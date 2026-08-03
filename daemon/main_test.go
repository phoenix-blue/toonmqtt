package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"math"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type bufferConn struct {
	bytes.Buffer
}

func (c *bufferConn) Read([]byte) (int, error)         { return 0, io.EOF }
func (c *bufferConn) Close() error                     { return nil }
func (c *bufferConn) LocalAddr() net.Addr              { return &net.IPAddr{} }
func (c *bufferConn) RemoteAddr() net.Addr             { return &net.IPAddr{} }
func (c *bufferConn) SetDeadline(time.Time) error      { return nil }
func (c *bufferConn) SetReadDeadline(time.Time) error  { return nil }
func (c *bufferConn) SetWriteDeadline(time.Time) error { return nil }

func closeEnough(a, b float64) bool {
	return math.Abs(a-b) < 0.001
}

func TestDefaultConfigUsesPlainMQTT(t *testing.T) {
	got := defaultConfig()
	if got.Platform != "mqtt" {
		t.Fatalf("default platform = %q, want mqtt", got.Platform)
	}
	if got.Discovery {
		t.Fatal("Home Assistant discovery must be disabled by default")
	}
}

func TestOpenThermF88(t *testing.T) {
	if got := openThermF88(0x15, 0x80); !closeEnough(got, 21.5) {
		t.Fatalf("openThermF88(0x15, 0x80) = %v, want 21.5", got)
	}
	if got := openThermF88(0xff, 0x80); !closeEnough(got, -0.5) {
		t.Fatalf("openThermF88(0xff, 0x80) = %v, want -0.5", got)
	}
}

func TestParseOpenThermTable(t *testing.T) {
	body := []byte(`
		{'dataId':'15','value0':'18','value1':'14','updated':'42'}
		{'dataId':'18','value0':'01','value1':'80','updated':'42'}
		{'dataId':'25','value0':'3c','value1':'80','updated':'42'}
		{'dataId':'28','value0':'2d','value1':'40','updated':'42'}
		{'dataId':'116','value0':'04','value1':'d2','updated':'42'}
		{'dataId':'125','value0':'02','value1':'08','updated':'42'}
	`)
	var got Telemetry
	parseOpenThermTable(body, &got)

	if got.MaxBoilerCapacity == nil || *got.MaxBoilerCapacity != 24 {
		t.Fatalf("MaxBoilerCapacity = %v, want 24", got.MaxBoilerCapacity)
	}
	if got.MinModulationLevel == nil || *got.MinModulationLevel != 20 {
		t.Fatalf("MinModulationLevel = %v, want 20", got.MinModulationLevel)
	}
	if got.BoilerPressure == nil || !closeEnough(*got.BoilerPressure, 1.5) {
		t.Fatalf("BoilerPressure = %v, want 1.5", got.BoilerPressure)
	}
	if got.BoilerFlowTemperature == nil || !closeEnough(*got.BoilerFlowTemperature, 60.5) {
		t.Fatalf("BoilerFlowTemperature = %v, want 60.5", got.BoilerFlowTemperature)
	}
	if got.BoilerReturnTemperature == nil || !closeEnough(*got.BoilerReturnTemperature, 45.3) {
		t.Fatalf("BoilerReturnTemperature = %v, want 45.3", got.BoilerReturnTemperature)
	}
	if got.BurnerStarts == nil || *got.BurnerStarts != 1234 {
		t.Fatalf("BurnerStarts = %v, want 1234", got.BurnerStarts)
	}
	if got.OpenThermSlaveVersion == nil || !closeEnough(*got.OpenThermSlaveVersion, 2.03) {
		t.Fatalf("OpenThermSlaveVersion = %v, want 2.03", got.OpenThermSlaveVersion)
	}
}

func TestParseOpenThermTableSkipsNeverUpdatedAndInvalidValues(t *testing.T) {
	body := []byte(`
		{'dataId':'25','value0':'50','value1':'00','updated':'0'}
		{'dataId':'18','value0':'09','value1':'00','updated':'12'}
	`)
	var got Telemetry
	parseOpenThermTable(body, &got)

	if got.BoilerFlowTemperature != nil {
		t.Fatalf("never-updated value was published: %v", *got.BoilerFlowTemperature)
	}
	if got.BoilerPressure != nil {
		t.Fatalf("out-of-range pressure was published: %v", *got.BoilerPressure)
	}
}

func TestPointDefaultsAndFiltering(t *testing.T) {
	c := defaultConfig()
	if !pointPublished(c, "current_temperature") || !pointWritable(c, "setpoint") {
		t.Fatal("expected backward-compatible point defaults")
	}
	point := c.Points["humidity"]
	point.Publish = false
	c.Points["humidity"] = point
	temperature, humidity := 21.5, 48.0
	state := filteredState(c, Telemetry{
		Timestamp:          "2026-08-03T00:00:00+02:00",
		CurrentTemperature: &temperature,
		Humidity:           &humidity,
	})
	if _, ok := state["humidity"]; ok {
		t.Fatal("disabled humidity was still added to state")
	}
	if got := state["current_temperature"]; got == nil {
		t.Fatal("enabled temperature is missing from state")
	}
}

func TestLegacyConfigWithoutPointsKeepsPreviousBehaviour(t *testing.T) {
	legacy := defaultConfig()
	legacy.Points = nil
	b, err := json.Marshal(legacy)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "toon-mqtt.json")
	if err := os.WriteFile(path, b, 0o600); err != nil {
		t.Fatal(err)
	}
	loaded, err := loadConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	if !pointPublished(loaded, "current_temperature") || !pointWritable(loaded, "setpoint") {
		t.Fatal("legacy config did not receive backward-compatible point defaults")
	}
	if pointPublished(loaded, "system_load_1m") {
		t.Fatal("optional hardware diagnostics must remain off by default")
	}
}

func TestEnergyJSONSkipsDisabledInjectionPoints(t *testing.T) {
	c := defaultConfig()
	for _, id := range []string{"inject_power_w", "inject_production_w"} {
		point := c.Points[id]
		point.Write = false
		c.Points[id] = point
	}
	err := applyEnergyJSON(nil, c, &EnergyState{}, `{"power_w":321,"production_w":654}`)
	if err == nil || !strings.Contains(err.Error(), "geen ingeschakelde waarden") {
		t.Fatalf("disabled energy JSON error = %v", err)
	}
}

func TestCleanPointConfig(t *testing.T) {
	c := defaultConfig()
	c.Points["setpoint"] = PointConfig{Publish: true, Write: true, Name: "  Woonkamer doel  "}
	c.Points["humidity"] = PointConfig{Publish: true, Write: true, Name: ""}
	cleaned, err := cleanConfig(c)
	if err != nil {
		t.Fatal(err)
	}
	if got := cleaned.Points["setpoint"].Name; got != "Woonkamer doel" {
		t.Fatalf("trimmed name = %q", got)
	}
	if cleaned.Points["humidity"].Write {
		t.Fatal("read-only point became writable")
	}
	if got := cleaned.Points["humidity"].Name; got != "Luchtvochtigheid" {
		t.Fatalf("fallback name = %q", got)
	}
}

func TestConfigRejectsUnsafeTopicsAndOversizedCredentials(t *testing.T) {
	c := defaultConfig()
	c.BaseTopic = "toon/+/onveilig"
	if _, err := cleanConfig(c); err == nil {
		t.Fatal("MQTT wildcard in base topic was accepted")
	}
	c = defaultConfig()
	c.Password = strings.Repeat("x", 513)
	if _, err := cleanConfig(c); err == nil {
		t.Fatal("oversized password was accepted")
	}
}

func TestStateSnapshotOnlyChangesForTelemetryChanges(t *testing.T) {
	c := defaultConfig()
	temperature, humidity := 21.5, 48.0
	one := stateSnapshot(c, Telemetry{CurrentTemperature: &temperature, Humidity: &humidity})
	two := stateSnapshot(c, Telemetry{CurrentTemperature: &temperature, Humidity: &humidity})
	if !snapshotsEqual(one, two) {
		t.Fatal("equal telemetry produced a changed snapshot")
	}
	humidity = 49
	three := stateSnapshot(c, Telemetry{CurrentTemperature: &temperature, Humidity: &humidity})
	if snapshotsEqual(one, three) {
		t.Fatal("changed telemetry was not detected")
	}
}

func TestPublishStateDeltaSkipsUnchangedTelemetry(t *testing.T) {
	c := defaultConfig()
	temperature := 21.5
	telemetry := Telemetry{Timestamp: "2026-08-03T12:00:00+02:00", CurrentTemperature: &temperature}
	conn := &bufferConn{}
	m := mqttClient{conn: conn}
	snapshot, published, err := publishStateDelta(&m, c, telemetry, nil, true)
	if err != nil || !published {
		t.Fatalf("initial publish = published %v error %v", published, err)
	}
	initialBytes := conn.Len()
	_, published, err = publishStateDelta(&m, c, telemetry, snapshot, false)
	if err != nil || published {
		t.Fatalf("unchanged publish = published %v error %v", published, err)
	}
	if conn.Len() != initialBytes {
		t.Fatal("unchanged telemetry wrote MQTT bytes")
	}
	temperature = 22
	telemetry.CurrentTemperature = &temperature
	_, published, err = publishStateDelta(&m, c, telemetry, snapshot, false)
	if err != nil || !published || conn.Len() <= initialBytes {
		t.Fatalf("changed publish = published %v error %v", published, err)
	}
}

func TestPointAvailabilityAndSources(t *testing.T) {
	c := defaultConfig()
	temperature, tvoc := 21.5, 125.0
	seen := map[string]string{}
	statuses := pointRuntimeStatuses(c, Telemetry{
		Timestamp: "2026-08-03T12:00:00+02:00", CurrentTemperature: &temperature, TVOC: &tvoc,
	}, EnergyState{}, seen)
	if !statuses["current_temperature"].Available || statuses["current_temperature"].Source != "Toon-thermostaat" {
		t.Fatalf("temperature status = %#v", statuses["current_temperature"])
	}
	if !statuses["tvoc_ppb"].Available || statuses["tvoc_ppb"].Source != "BXT-sensor" {
		t.Fatalf("TVOC status = %#v", statuses["tvoc_ppb"])
	}
	if statuses["boiler_pressure_bar"].Available {
		t.Fatal("never-seen OpenTherm pressure was marked available")
	}
	if !statuses["inject_power_w"].Available {
		t.Fatal("provided injection endpoint was marked unavailable")
	}
}

func TestSourceConflictDetectionHonoursInjectionSelection(t *testing.T) {
	c := defaultConfig()
	production := 750.0
	telemetry := Telemetry{PowerProduction: &production}
	conflicts := detectSourceConflicts(c, telemetry, EnergyState{}, time.Now())
	if conflicts["inject_production_w"] == "" {
		t.Fatal("existing production source was not detected")
	}
	point := c.Points["inject_production_w"]
	point.Write = false
	c.Points["inject_production_w"] = point
	if got := detectSourceConflicts(c, telemetry, EnergyState{}, time.Now()); len(got) != 0 {
		t.Fatalf("disabled injection reported a conflict: %#v", got)
	}
}

func TestNoThermostatWarningForQubyNoErrorSentinel(t *testing.T) {
	noError := 255
	if warnings := runtimeWarnings(Telemetry{ErrorCode: &noError}); len(warnings) != 0 {
		t.Fatalf("Quby no-error sentinel produced warnings: %#v", warnings)
	}
}

func TestSafeDiagnosticsOmitPrivateConfiguration(t *testing.T) {
	c := defaultConfig()
	c.Host = "private-broker.example"
	c.Username = "private-user"
	c.Password = "private-password"
	c.BaseTopic = "private/topic"
	c.Points["setpoint"] = PointConfig{Publish: true, Write: true, Name: "Privékamer"}
	path := filepath.Join(t.TempDir(), "diagnostics.json")
	if err := writeDiagnosticsTo(path, c, Status{Connected: true}); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	text := string(b)
	for _, secret := range []string{c.Host, c.Username, c.Password, c.BaseTopic, "Privékamer"} {
		if strings.Contains(text, secret) {
			t.Fatalf("diagnostics contain private value %q", secret)
		}
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("diagnostics mode = %o, want 600", info.Mode().Perm())
	}
}

func TestMQTTPacketSizeLimit(t *testing.T) {
	packetData := []byte{0x30}
	packetData = append(packetData, remainingLength(maxMQTTPacket+1)...)
	m := mqttClient{r: bufio.NewReader(bytes.NewReader(packetData))}
	if _, _, err := m.readPacket(); err == nil || !strings.Contains(err.Error(), "1 MiB") {
		t.Fatalf("oversized packet error = %v", err)
	}
}

func TestPreviousBaseTopicRetainedStateIsCleared(t *testing.T) {
	client, server := net.Pipe()
	m := mqttClient{conn: client}
	var captured bytes.Buffer
	readDone := make(chan struct{})
	go func() {
		_, _ = io.Copy(&captured, server)
		close(readDone)
	}()
	previous := defaultConfig()
	previous.BaseTopic = "toon/oud"
	next := previous
	next.BaseTopic = "toon/nieuw"
	if err := cleanupPreviousNamespace(&m, previous, next); err != nil {
		t.Fatal(err)
	}
	_ = client.Close()
	<-readDone
	_ = server.Close()
	data := captured.String()
	if !strings.Contains(data, "toon/oud/availability") || !strings.Contains(data, "toon/oud/state") {
		t.Fatal("old retained namespace was not cleared")
	}
	if strings.Contains(data, "toon/nieuw") {
		t.Fatal("cleanup wrote into the new namespace")
	}
}

func TestParseCPUTicks(t *testing.T) {
	total, idle, ok := parseCPUTicks("cpu  10 2 3 40 5 6 7 8 0 0")
	if !ok || total != 81 || idle != 45 {
		t.Fatalf("parseCPUTicks = total %d idle %d ok %v", total, idle, ok)
	}
}

func TestParseMemInfo(t *testing.T) {
	available, used := parseMemInfo("MemTotal: 500000 kB\nMemAvailable: 200000 kB\n")
	if available == nil || !closeEnough(*available, 195.3) {
		t.Fatalf("available MB = %v", available)
	}
	if used == nil || !closeEnough(*used, 60) {
		t.Fatalf("used percent = %v", used)
	}
}

func TestWatchPathRemovalWithoutMQTTConnection(t *testing.T) {
	appDir := filepath.Join(t.TempDir(), "toonmqtt")
	if err := os.Mkdir(appDir, 0o755); err != nil {
		t.Fatal(err)
	}

	removed := make(chan struct{})
	go watchPathRemoval(appDir, 30*time.Millisecond, 5*time.Millisecond, func() {
		close(removed)
	})

	if err := os.Remove(appDir); err != nil {
		t.Fatal(err)
	}

	select {
	case <-removed:
	case <-time.After(time.Second):
		t.Fatal("app removal was not detected without an MQTT connection")
	}
}
