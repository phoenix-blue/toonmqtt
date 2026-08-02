package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	configPath      = "/mnt/data/tsc/toon-mqtt.json"
	statusPath      = "/var/volatile/tmp/toon-mqtt-status.json"
	controlPath     = "/mnt/data/tsc/toon-mqtt-control"
	energyStatePath = "/mnt/data/tsc/toon-mqtt-energy.json"
	backupPath      = "/mnt/data/tsc/backups/toonmqtt-energy-original"
	appPath         = "/qmf/qml/apps/toonmqtt"
	version         = "1.2.4"
)

var (
	errReload = errors.New("configuration reload requested")
)

type Config struct {
	Host            string `json:"host"`
	Port            int    `json:"port"`
	Username        string `json:"username"`
	Password        string `json:"password"`
	BaseTopic       string `json:"base_topic"`
	Platform        string `json:"platform"`
	DiscoveryPrefix string `json:"discovery_prefix"`
	Discovery       bool   `json:"discovery"`
	ControlEnabled  bool   `json:"control_enabled"`
	IntervalSeconds int    `json:"interval_seconds"`
	EnergyInjection bool   `json:"energy_injection"`
	EnergyTimeout   int    `json:"energy_timeout_seconds"`
}

type Status struct {
	Connected    bool   `json:"connected"`
	Broker       string `json:"broker"`
	LastPublish  string `json:"last_publish,omitempty"`
	LastCommand  string `json:"last_command,omitempty"`
	LastTest     string `json:"last_test,omitempty"`
	TestResult   string `json:"test_result,omitempty"`
	EnergyOnline bool   `json:"energy_online"`
	LastEnergy   string `json:"last_energy_update,omitempty"`
	LastError    string `json:"last_error,omitempty"`
	Version      string `json:"version"`
}

type EnergyState struct {
	PowerW        *float64 `json:"power_w,omitempty"`
	ProductionW   *float64 `json:"production_w,omitempty"`
	ImportLowKWh  *float64 `json:"import_low_kwh,omitempty"`
	ImportHighKWh *float64 `json:"import_high_kwh,omitempty"`
	ExportLowKWh  *float64 `json:"export_low_kwh,omitempty"`
	ExportHighKWh *float64 `json:"export_high_kwh,omitempty"`
	GasTotalM3    *float64 `json:"gas_total_m3,omitempty"`
	LastUpdate    string   `json:"last_update,omitempty"`
}

type ThermostatInfo struct {
	Result                        string `json:"result"`
	CurrentTemp                   string `json:"currentTemp"`
	CurrentSetpoint               string `json:"currentSetpoint"`
	CurrentInternalBoilerSetpoint string `json:"currentInternalBoilerSetpoint"`
	ProgramState                  string `json:"programState"`
	ActiveState                   string `json:"activeState"`
	BurnerInfo                    string `json:"burnerInfo"`
	OTCommError                   string `json:"otCommError"`
	ErrorFound                    string `json:"errorFound"`
	Connection                    string `json:"connection"`
	CurrentModulationLevel        string `json:"currentModulationLevel"`
}

type Telemetry struct {
	Timestamp                 string   `json:"timestamp"`
	CurrentTemperature        *float64 `json:"current_temperature,omitempty"`
	Setpoint                  *float64 `json:"setpoint,omitempty"`
	InternalBoilerSetpoint    *float64 `json:"internal_boiler_setpoint,omitempty"`
	ProgramState              *int     `json:"program_state,omitempty"`
	Program                   string   `json:"program,omitempty"`
	ActiveState               *int     `json:"active_state,omitempty"`
	Preset                    string   `json:"preset,omitempty"`
	BurnerState               *int     `json:"burner_state,omitempty"`
	Burner                    string   `json:"burner,omitempty"`
	HVACAction                string   `json:"hvac_action,omitempty"`
	BurnerActive              *int     `json:"burner_active,omitempty"`
	DHWActive                 *int     `json:"dhw_active,omitempty"`
	Modulation                *float64 `json:"modulation_percent,omitempty"`
	OpenThermCommunicationErr *int     `json:"opentherm_communication_error,omitempty"`
	ErrorCode                 *int     `json:"error_code,omitempty"`
	ThermostatConnection      *int     `json:"thermostat_connection,omitempty"`
	BoilerFlowTemperature     *float64 `json:"boiler_flow_temperature,omitempty"`
	BoilerReturnTemperature   *float64 `json:"boiler_return_temperature,omitempty"`
	BoilerPressure            *float64 `json:"boiler_pressure_bar,omitempty"`
	DHWTemperature            *float64 `json:"dhw_temperature,omitempty"`
	DHWFlowRate               *float64 `json:"dhw_flow_rate_lpm,omitempty"`
	OutsideTemperature        *float64 `json:"outside_temperature,omitempty"`
	BoilerExhaustTemperature  *float64 `json:"boiler_exhaust_temperature,omitempty"`
	MaxBoilerCapacity         *int     `json:"max_boiler_capacity_kw,omitempty"`
	MinModulationLevel        *int     `json:"min_modulation_level_percent,omitempty"`
	OEMDiagnosticCode         *int     `json:"opentherm_oem_diagnostic_code,omitempty"`
	BurnerStarts              *int     `json:"burner_starts,omitempty"`
	CHPumpStarts              *int     `json:"ch_pump_starts,omitempty"`
	DHWPumpStarts             *int     `json:"dhw_pump_starts,omitempty"`
	DHWBurnerStarts           *int     `json:"dhw_burner_starts,omitempty"`
	BurnerHours               *int     `json:"burner_hours,omitempty"`
	CHPumpHours               *int     `json:"ch_pump_hours,omitempty"`
	DHWPumpHours              *int     `json:"dhw_pump_hours,omitempty"`
	DHWBurnerHours            *int     `json:"dhw_burner_hours,omitempty"`
	OpenThermSlaveVersion     *float64 `json:"opentherm_slave_version,omitempty"`
	Humidity                  *float64 `json:"humidity,omitempty"`
	PrimaryTemperature        *float64 `json:"primary_temperature,omitempty"`
	PrimaryHumidity           *float64 `json:"primary_humidity,omitempty"`
	TVOC                      *float64 `json:"tvoc_ppb,omitempty"`
	ECO2                      *float64 `json:"eco2_ppm,omitempty"`
	PowerUsage                *float64 `json:"power_usage_w,omitempty"`
	PowerUsageAverage         *float64 `json:"power_usage_average_w,omitempty"`
	PowerProduction           *float64 `json:"power_production_w,omitempty"`
	PowerProductionAverage    *float64 `json:"power_production_average_w,omitempty"`
	GasUsage                  *float64 `json:"gas_usage_lph,omitempty"`
	GasUsageAverage           *float64 `json:"gas_usage_average_lph,omitempty"`
	DHWEnabled                *int     `json:"dhw_enabled,omitempty"`
	DHWSetpoint               *float64 `json:"dhw_setpoint,omitempty"`
	MaxHeaterTemperature      *float64 `json:"max_heater_temperature,omitempty"`
	MaxHeatingRate            *float64 `json:"max_heating_rate,omitempty"`
	HeatingType               *int     `json:"heating_type,omitempty"`
	HeaterFuelType            string   `json:"heater_fuel_type,omitempty"`
	TemperatureOffset         *float64 `json:"temperature_offset,omitempty"`
}

type mqttMessage struct {
	topic   string
	payload []byte
}

type mqttClient struct {
	conn net.Conn
	r    *bufio.Reader
	mu   sync.Mutex
}

func defaultConfig() Config {
	return Config{
		Host: "127.0.0.1", Port: 1883, Username: "",
		Password: "", BaseTopic: "toon/voorbeeld",
		Platform: "mqtt", DiscoveryPrefix: "homeassistant",
		Discovery: false, ControlEnabled: true, IntervalSeconds: 30,
		EnergyInjection: true, EnergyTimeout: 180,
	}
}

func cleanConfig(c Config) (Config, error) {
	c.Host = strings.TrimSpace(c.Host)
	c.BaseTopic = strings.Trim(strings.TrimSpace(c.BaseTopic), "/")
	c.Platform = strings.ToLower(strings.TrimSpace(c.Platform))
	switch c.Platform {
	case "":
		c.Platform = "mqtt"
	case "home assistant", "ha":
		c.Platform = "homeassistant"
	case "standard", "standaard", "generic", "normal", "normaal":
		c.Platform = "mqtt"
	case "open hab":
		c.Platform = "openhab"
	}
	switch c.Platform {
	case "mqtt", "homeassistant", "domoticz", "openhab":
	default:
		return c, errors.New("platform is mqtt, homeassistant, domoticz of openhab")
	}
	c.DiscoveryPrefix = strings.Trim(strings.TrimSpace(c.DiscoveryPrefix), "/")
	if c.Host == "" || c.BaseTopic == "" {
		return c, errors.New("host en base_topic zijn verplicht")
	}
	if c.Port < 1 || c.Port > 65535 {
		return c, errors.New("ongeldige MQTT-poort")
	}
	if c.IntervalSeconds < 5 {
		c.IntervalSeconds = 5
	}
	if c.IntervalSeconds > 3600 {
		c.IntervalSeconds = 3600
	}
	if c.DiscoveryPrefix == "" {
		c.DiscoveryPrefix = "homeassistant"
	}
	if c.EnergyTimeout < 30 {
		c.EnergyTimeout = 30
	}
	if c.EnergyTimeout > 86400 {
		c.EnergyTimeout = 86400
	}
	return c, nil
}

func loadConfig(path string) (Config, error) {
	c := defaultConfig()
	b, err := os.ReadFile(path)
	if err != nil {
		return c, err
	}
	if err := json.Unmarshal(b, &c); err != nil {
		return c, err
	}
	return cleanConfig(c)
}

func writeStatus(s Status) {
	s.Version = version
	b, _ := json.Marshal(s)
	tmp := statusPath + ".tmp"
	if os.WriteFile(tmp, b, 0644) == nil {
		_ = os.Rename(tmp, statusPath)
	}
}

func loadEnergyState() EnergyState {
	var state EnergyState
	b, err := os.ReadFile(energyStatePath)
	if err == nil {
		_ = json.Unmarshal(b, &state)
	}
	return state
}

func saveEnergyState(state EnergyState) {
	b, _ := json.MarshalIndent(state, "", "\t")
	tmp := energyStatePath + ".tmp"
	if os.WriteFile(tmp, b, 0644) == nil {
		_ = os.Rename(tmp, energyStatePath)
	}
}

func mqttString(s string) []byte {
	b := []byte(s)
	out := make([]byte, 2+len(b))
	binary.BigEndian.PutUint16(out[:2], uint16(len(b)))
	copy(out[2:], b)
	return out
}

func remainingLength(n int) []byte {
	var out []byte
	for {
		d := byte(n % 128)
		n /= 128
		if n > 0 {
			d |= 128
		}
		out = append(out, d)
		if n == 0 {
			return out
		}
	}
}

func packet(header byte, body []byte) []byte {
	p := []byte{header}
	p = append(p, remainingLength(len(body))...)
	return append(p, body...)
}

func connectMQTT(c Config, withAvailabilityWill bool) (*mqttClient, error) {
	conn, err := net.DialTimeout("tcp", net.JoinHostPort(c.Host, strconv.Itoa(c.Port)), 8*time.Second)
	if err != nil {
		return nil, err
	}
	m := &mqttClient{conn: conn, r: bufio.NewReader(conn)}
	clientID := fmt.Sprintf("toon-%d", time.Now().Unix()%1000000)
	flags := byte(0x02)
	if withAvailabilityWill {
		flags |= 0x04 | 0x08
	}
	if c.Username != "" {
		flags |= 0x80
	}
	if c.Password != "" {
		flags |= 0x40
	}
	var body []byte
	body = append(body, mqttString("MQTT")...)
	body = append(body, 4, flags, 0, 30)
	body = append(body, mqttString(clientID)...)
	if withAvailabilityWill {
		body = append(body, mqttString(c.BaseTopic+"/availability")...)
		body = append(body, mqttString("offline")...)
	}
	if c.Username != "" {
		body = append(body, mqttString(c.Username)...)
	}
	if c.Password != "" {
		body = append(body, mqttString(c.Password)...)
	}
	if _, err := conn.Write(packet(0x10, body)); err != nil {
		conn.Close()
		return nil, err
	}
	_ = conn.SetReadDeadline(time.Now().Add(8 * time.Second))
	h, payload, err := m.readPacket()
	_ = conn.SetReadDeadline(time.Time{})
	if err != nil {
		conn.Close()
		return nil, err
	}
	if h>>4 != 2 || len(payload) < 2 || payload[1] != 0 {
		conn.Close()
		code := byte(255)
		if len(payload) > 1 {
			code = payload[1]
		}
		return nil, fmt.Errorf("broker weigert verbinding (CONNACK %d)", code)
	}
	return m, nil
}

func (m *mqttClient) write(p []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	_ = m.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
	_, err := m.conn.Write(p)
	_ = m.conn.SetWriteDeadline(time.Time{})
	return err
}

func (m *mqttClient) publish(topic string, payload []byte, retain bool) error {
	h := byte(0x30)
	if retain {
		h |= 1
	}
	body := append(mqttString(topic), payload...)
	return m.write(packet(h, body))
}

func (m *mqttClient) subscribe(topic string) error {
	body := []byte{0, 1}
	body = append(body, mqttString(topic)...)
	body = append(body, 0)
	return m.write(packet(0x82, body))
}

func (m *mqttClient) readPacket() (byte, []byte, error) {
	h, err := m.r.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	mult, n := 1, 0
	for i := 0; i < 4; i++ {
		b, err := m.r.ReadByte()
		if err != nil {
			return 0, nil, err
		}
		n += int(b&127) * mult
		if b&128 == 0 {
			break
		}
		mult *= 128
	}
	p := make([]byte, n)
	_, err = io.ReadFull(m.r, p)
	return h, p, err
}

func (m *mqttClient) reader(messages chan<- mqttMessage, errs chan<- error) {
	for {
		h, p, err := m.readPacket()
		if err != nil {
			errs <- err
			return
		}
		switch h >> 4 {
		case 3:
			if len(p) < 2 {
				continue
			}
			n := int(binary.BigEndian.Uint16(p[:2]))
			if n+2 > len(p) {
				continue
			}
			offset := 2 + n
			qos := (h >> 1) & 3
			if qos > 0 {
				offset += 2
			}
			if offset <= len(p) {
				messages <- mqttMessage{string(p[2 : 2+n]), append([]byte(nil), p[offset:]...)}
			}
		case 12:
			_ = m.write(packet(0xD0, nil))
		}
	}
}

func ptrFloat(v float64) *float64 { return &v }
func ptrInt(v int) *int           { return &v }

func parseFloatString(s string, scale float64) *float64 {
	v, err := strconv.ParseFloat(strings.TrimSpace(s), 64)
	if err != nil {
		return nil
	}
	v /= scale
	return &v
}

func parseIntString(s string) *int {
	v, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil {
		return nil
	}
	return &v
}

func readNumber(path string, divisor float64) *float64 {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	v, err := strconv.ParseFloat(strings.TrimSpace(string(b)), 64)
	if err != nil {
		return nil
	}
	v /= divisor
	return &v
}

func readJSON(url string, out any) error {
	client := http.Client{Timeout: 4 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 1024*1024)).Decode(out)
}

var openThermRowRE = regexp.MustCompile(
	`\{'dataId':'([0-9]+)'\s*,\s*'value0':'([0-9A-Fa-f]{2})'\s*,\s*'value1':'([0-9A-Fa-f]{2})'\s*,\s*'updated':'([^']*)'`,
)

func openThermF88(high, low byte) float64 {
	return float64(int16(uint16(high)<<8|uint16(low))) / 256
}

func openThermU16(high, low byte) int {
	return int(uint16(high)<<8 | uint16(low))
}

func parseOpenThermTable(body []byte, t *Telemetry) {
	for _, row := range openThermRowRE.FindAllSubmatch(body, -1) {
		updated, err := strconv.ParseInt(string(row[4]), 10, 64)
		if err != nil || updated <= 0 {
			continue
		}
		id, errID := strconv.Atoi(string(row[1]))
		high64, errHigh := strconv.ParseUint(string(row[2]), 16, 8)
		low64, errLow := strconv.ParseUint(string(row[3]), 16, 8)
		if errID != nil || errHigh != nil || errLow != nil {
			continue
		}
		high, low := byte(high64), byte(low64)
		f88 := openThermF88(high, low)
		u16 := openThermU16(high, low)
		switch id {
		case 15:
			t.MaxBoilerCapacity = ptrInt(int(high))
			t.MinModulationLevel = ptrInt(int(low))
		case 18:
			if f88 >= 0 && f88 <= 5 {
				t.BoilerPressure = ptrFloat(math.Round(f88*100) / 100)
			}
		case 19:
			if f88 >= 0 && f88 <= 16 {
				t.DHWFlowRate = ptrFloat(math.Round(f88*100) / 100)
			}
		case 25:
			if f88 >= -40 && f88 <= 127 {
				t.BoilerFlowTemperature = ptrFloat(math.Round(f88*10) / 10)
			}
		case 26:
			if f88 >= -40 && f88 <= 127 {
				t.DHWTemperature = ptrFloat(math.Round(f88*10) / 10)
			}
		case 27:
			if f88 >= -40 && f88 <= 127 {
				t.OutsideTemperature = ptrFloat(math.Round(f88*10) / 10)
			}
		case 28:
			if f88 >= -40 && f88 <= 127 {
				t.BoilerReturnTemperature = ptrFloat(math.Round(f88*10) / 10)
			}
		case 33:
			exhaust := int(int16(uint16(high)<<8 | uint16(low)))
			if exhaust >= -40 && exhaust <= 500 {
				t.BoilerExhaustTemperature = ptrFloat(float64(exhaust))
			}
		case 115:
			t.OEMDiagnosticCode = ptrInt(u16)
		case 116:
			t.BurnerStarts = ptrInt(u16)
		case 117:
			t.CHPumpStarts = ptrInt(u16)
		case 118:
			t.DHWPumpStarts = ptrInt(u16)
		case 119:
			t.DHWBurnerStarts = ptrInt(u16)
		case 120:
			t.BurnerHours = ptrInt(u16)
		case 121:
			t.CHPumpHours = ptrInt(u16)
		case 122:
			t.DHWPumpHours = ptrInt(u16)
		case 123:
			t.DHWBurnerHours = ptrInt(u16)
		case 125:
			if f88 >= 0 && f88 <= 20 {
				t.OpenThermSlaveVersion = ptrFloat(math.Round(f88*100) / 100)
			}
		}
	}
}

func collectOpenThermTelemetry(t *Telemetry) {
	client := http.Client{Timeout: 4 * time.Second}
	resp, err := client.Get("http://127.0.0.1/happ_thermstat?action=printTableInfo")
	if err != nil {
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err == nil {
		parseOpenThermTable(body, t)
	}
}

func runBXT(service, action string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	a := []string{"-c", "-d", ":happ_thermstat"}
	if service != "" {
		a = append(a, "-s", service)
	}
	a = append(a, "-n", action)
	for i := 0; i+1 < len(args); i += 2 {
		a = append(a, "-a", args[i], "-v", args[i+1])
	}
	a = append(a, "-r", "-w", "-1")
	out, err := exec.CommandContext(ctx, "/qmf/bin/bxt", a...).CombinedOutput()
	if ctx.Err() != nil {
		return string(out), ctx.Err()
	}
	return string(out), err
}

func invokeBXT(service, action string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	a := []string{"-c", "-d", ":happ_thermstat"}
	if service != "" {
		a = append(a, "-s", service)
	}
	a = append(a, "-n", action)
	for i := 0; i+1 < len(args); i += 2 {
		a = append(a, "-a", args[i], "-v", args[i+1])
	}
	a = append(a, "-w", "0")
	out, err := exec.CommandContext(ctx, "/qmf/bin/bxt", a...).CombinedOutput()
	if ctx.Err() != nil {
		return string(out), ctx.Err()
	}
	return string(out), err
}

func xmlValue(s, name string) string {
	r := regexp.MustCompile("<" + regexp.QuoteMeta(name) + ">([^<]*)</" + regexp.QuoteMeta(name) + ">")
	m := r.FindStringSubmatch(s)
	if len(m) == 2 {
		return strings.TrimSpace(m[1])
	}
	return ""
}

func collectTelemetry() Telemetry {
	t := Telemetry{Timestamp: time.Now().Format(time.RFC3339)}
	var th ThermostatInfo
	if readJSON("http://127.0.0.1/happ_thermstat?action=getThermostatInfo", &th) == nil && th.Result == "ok" {
		t.CurrentTemperature = parseFloatString(th.CurrentTemp, 100)
		t.Setpoint = parseFloatString(th.CurrentSetpoint, 100)
		t.InternalBoilerSetpoint = parseFloatString(th.CurrentInternalBoilerSetpoint, 1)
		t.ProgramState = parseIntString(th.ProgramState)
		t.ActiveState = parseIntString(th.ActiveState)
		t.BurnerState = parseIntString(th.BurnerInfo)
		t.Modulation = parseFloatString(th.CurrentModulationLevel, 1)
		t.OpenThermCommunicationErr = parseIntString(th.OTCommError)
		t.ErrorCode = parseIntString(th.ErrorFound)
		t.ThermostatConnection = parseIntString(th.Connection)
		if t.ProgramState != nil && *t.ProgramState == 1 {
			t.Program = "schedule"
		} else {
			t.Program = "manual"
		}
		presets := map[int]string{0: "comfort", 1: "home", 2: "sleep", 3: "away", 4: "holiday", 6: "manual"}
		if t.ActiveState != nil {
			t.Preset = presets[*t.ActiveState]
		}
		burners := map[int]string{0: "off", 1: "heating", 2: "hot_water", 3: "preheat"}
		if t.BurnerState != nil {
			t.Burner = burners[*t.BurnerState]
			burnerActive := 0
			dhwActive := 0
			if *t.BurnerState > 0 {
				burnerActive = 1
			}
			if *t.BurnerState == 2 || *t.BurnerState == 3 {
				dhwActive = 1
			}
			t.BurnerActive = ptrInt(burnerActive)
			t.DHWActive = ptrInt(dhwActive)
			t.HVACAction = "idle"
			if *t.BurnerState == 1 {
				t.HVACAction = "heating"
			}
		}
	}
	t.PrimaryTemperature = readNumber("/sys/bus/i2c/devices/3-0043/temp", 1000)
	t.PrimaryHumidity = readNumber("/sys/bus/i2c/devices/3-0043/humidity", 1000)
	if t.CurrentTemperature != nil && t.PrimaryTemperature != nil && t.PrimaryHumidity != nil {
		sp := 6.11 * math.Pow(10, 7.5**t.PrimaryTemperature/(237.7+*t.PrimaryTemperature))
		sa := 6.11 * math.Pow(10, 7.5**t.CurrentTemperature/(237.7+*t.CurrentTemperature))
		rh := *t.PrimaryHumidity * sp / sa
		if rh >= 0 && rh <= 100 {
			t.Humidity = ptrFloat(math.Round(rh*10) / 10)
		}
	}
	t.TVOC = readNumber("/var/volatile/tmp/tvoc", 1)
	t.ECO2 = readNumber("/var/volatile/tmp/eco2", 1)

	var usage struct {
		Result          string                             `json:"result"`
		PowerUsage      struct{ Value, AvgValue *float64 } `json:"powerUsage"`
		PowerProduction struct{ Value, AvgValue *float64 } `json:"powerProduction"`
		GasUsage        struct{ Value, AvgValue *float64 } `json:"gasUsage"`
	}
	if readJSON("http://127.0.0.1/happ_pwrusage?action=GetCurrentUsage", &usage) == nil && usage.Result == "ok" {
		t.PowerUsage, t.PowerUsageAverage = usage.PowerUsage.Value, usage.PowerUsage.AvgValue
		t.PowerProduction, t.PowerProductionAverage = usage.PowerProduction.Value, usage.PowerProduction.AvgValue
		t.GasUsage, t.GasUsageAverage = usage.GasUsage.Value, usage.GasUsage.AvgValue
	}
	if out, err := runBXT("Thermostat", "GetDhwSettings"); err == nil {
		t.DHWEnabled = parseIntString(xmlValue(out, "dhwEnabled"))
		t.DHWSetpoint = parseFloatString(xmlValue(out, "dhwSetpoint"), 1)
	}
	if out, err := runBXT("Thermostat", "GetChSettings"); err == nil {
		t.MaxHeaterTemperature = parseFloatString(xmlValue(out, "maxHeaterTemp"), 1)
		t.MaxHeatingRate = parseFloatString(xmlValue(out, "maxHeatingRate"), 1)
		t.HeatingType = parseIntString(xmlValue(out, "heatingType"))
		t.HeaterFuelType = xmlValue(out, "heaterFuelType")
	}
	if out, err := runBXT("Thermostat", "GetTempOffset"); err == nil {
		t.TemperatureOffset = parseFloatString(xmlValue(out, "offset"), 1)
	}
	collectOpenThermTelemetry(&t)
	return t
}

func publishState(m *mqttClient, c Config, t Telemetry) error {
	b, _ := json.Marshal(t)
	if err := m.publish(c.BaseTopic+"/state", b, true); err != nil {
		return err
	}
	vals := map[string]any{
		"current_temperature": t.CurrentTemperature, "temperature": t.CurrentTemperature, "setpoint": t.Setpoint,
		"program": t.Program, "preset": t.Preset, "hvac_mode": "heat", "hvac_action": t.HVACAction,
		"burner": t.Burner, "burner_active": t.BurnerActive, "dhw_active": t.DHWActive,
		"modulation_percent": t.Modulation, "humidity": t.Humidity,
		"primary_temperature": t.PrimaryTemperature, "primary_humidity": t.PrimaryHumidity,
		"tvoc_ppb": t.TVOC, "eco2_ppm": t.ECO2, "power_usage_w": t.PowerUsage,
		"power_usage_average_w": t.PowerUsageAverage,
		"power_production_w":    t.PowerProduction, "power_production_average_w": t.PowerProductionAverage,
		"gas_usage_lph": t.GasUsage, "gas_usage_average_lph": t.GasUsageAverage,
		"dhw_enabled": t.DHWEnabled, "dhw_setpoint": t.DHWSetpoint,
		"internal_boiler_setpoint": t.InternalBoilerSetpoint,
		"max_heater_temperature":   t.MaxHeaterTemperature, "max_heating_rate": t.MaxHeatingRate,
		"heating_type": t.HeatingType, "heater_fuel_type": t.HeaterFuelType,
		"temperature_offset":            t.TemperatureOffset,
		"opentherm_communication_error": t.OpenThermCommunicationErr,
		"thermostat_connection":         t.ThermostatConnection, "error_code": t.ErrorCode,
		"boiler_flow_temperature":   t.BoilerFlowTemperature,
		"boiler_return_temperature": t.BoilerReturnTemperature,
		"boiler_pressure_bar":       t.BoilerPressure, "dhw_temperature": t.DHWTemperature,
		"dhw_flow_rate_lpm": t.DHWFlowRate, "outside_temperature": t.OutsideTemperature,
		"boiler_exhaust_temperature":    t.BoilerExhaustTemperature,
		"max_boiler_capacity_kw":        t.MaxBoilerCapacity,
		"min_modulation_level_percent":  t.MinModulationLevel,
		"opentherm_oem_diagnostic_code": t.OEMDiagnosticCode,
		"burner_starts":                 t.BurnerStarts, "ch_pump_starts": t.CHPumpStarts,
		"dhw_pump_starts": t.DHWPumpStarts, "dhw_burner_starts": t.DHWBurnerStarts,
		"burner_hours": t.BurnerHours, "ch_pump_hours": t.CHPumpHours,
		"dhw_pump_hours": t.DHWPumpHours, "dhw_burner_hours": t.DHWBurnerHours,
		"opentherm_slave_version": t.OpenThermSlaveVersion,
	}
	for name, v := range vals {
		if v == nil || v == "" {
			continue
		}
		var data []byte
		switch x := v.(type) {
		case string:
			data = []byte(x)
		default:
			data, _ = json.Marshal(v)
		}
		if bytes.Equal(data, []byte("null")) {
			continue
		}
		if err := m.publish(c.BaseTopic+"/state/"+name, data, true); err != nil {
			return err
		}
	}
	return nil
}

func deviceBlock() map[string]any {
	return map[string]any{
		"identifiers": []string{"toon_local_mqtt"}, "name": "Toon",
		"manufacturer": "Eneco / Quby", "model": "Toon 2", "sw_version": version,
	}
}

func publishDiscovery(m *mqttClient, c Config) error {
	type entity struct {
		component string
		id        string
		cfg       map[string]any
	}
	base, prefix := c.BaseTopic, c.DiscoveryPrefix
	dev := deviceBlock()
	entities := []entity{
		{"climate", "thermostat", map[string]any{
			"name": "Thermostaat", "unique_id": "toon_local_thermostat", "device": dev,
			"current_temperature_topic": base + "/state/current_temperature",
			"current_humidity_topic":    base + "/state/humidity",
			"temperature_state_topic":   base + "/state/setpoint",
			"temperature_command_topic": base + "/set/setpoint",
			"action_topic":              base + "/state/hvac_action",
			"preset_mode_state_topic":   base + "/state/preset",
			"preset_mode_command_topic": base + "/set/preset",
			"preset_modes":              []string{"comfort", "home", "sleep", "away"},
			"mode_state_topic":          base + "/state/hvac_mode",
			"modes":                     []string{"heat"}, "min_temp": 6, "max_temp": 30, "temp_step": 0.5,
			"precision": 0.1, "temperature_unit": "C",
			"json_attributes_topic": base + "/state",
			"availability_topic":    base + "/availability", "payload_available": "online", "payload_not_available": "offline",
		}},
		{"switch", "program", map[string]any{
			"name": "Weekprogramma", "unique_id": "toon_local_program", "device": dev,
			"state_topic": base + "/state/program", "command_topic": base + "/set/program",
			"payload_on": "schedule", "payload_off": "manual", "state_on": "schedule", "state_off": "manual",
			"availability_topic": base + "/availability",
		}},
		{"switch", "dhw", map[string]any{
			"name": "Tapwater voorverwarmen", "unique_id": "toon_local_dhw", "device": dev,
			"state_topic": base + "/state/dhw_enabled", "command_topic": base + "/set/dhw_enabled",
			"payload_on": "1", "payload_off": "0", "state_on": "1", "state_off": "0",
			"availability_topic": base + "/availability",
		}},
	}
	sensors := []struct {
		id, name, unit, class, stateClass, category string
		enabledByDefault                            bool
	}{
		{"temperature", "Kamertemperatuur", "°C", "temperature", "measurement", "", true},
		{"humidity", "Luchtvochtigheid", "%", "humidity", "measurement", "", true},
		{"tvoc_ppb", "TVOC", "ppb", "volatile_organic_compounds_parts", "measurement", "", true},
		{"eco2_ppm", "Geschatte CO₂", "ppm", "carbon_dioxide", "measurement", "", true},
		{"modulation_percent", "Ketelmodulatie", "%", "", "measurement", "", true},
		{"internal_boiler_setpoint", "Ketel doeltemperatuur", "°C", "temperature", "measurement", "", true},
		{"boiler_flow_temperature", "Ketel aanvoertemperatuur", "°C", "temperature", "measurement", "", true},
		{"boiler_return_temperature", "Ketel retourtemperatuur", "°C", "temperature", "measurement", "", true},
		{"boiler_pressure_bar", "Cv-waterdruk", "bar", "pressure", "measurement", "", true},
		{"dhw_temperature", "Tapwatertemperatuur actueel", "°C", "temperature", "measurement", "", true},
		{"dhw_flow_rate_lpm", "Tapwaterdebiet", "L/min", "volume_flow_rate", "measurement", "", true},
		{"outside_temperature", "OpenTherm buitentemperatuur", "°C", "temperature", "measurement", "", true},
		{"boiler_exhaust_temperature", "Ketel rookgastemperatuur", "°C", "temperature", "measurement", "", true},
		{"power_usage_w", "Elektriciteitsverbruik", "W", "power", "measurement", "", true},
		{"power_usage_average_w", "Elektriciteitsverbruik gemiddeld", "W", "power", "measurement", "", true},
		{"power_production_w", "Elektriciteitsproductie", "W", "power", "measurement", "", true},
		{"power_production_average_w", "Elektriciteitsproductie gemiddeld", "W", "power", "measurement", "", true},
		{"gas_usage_lph", "Gasdebiet", "L/h", "volume_flow_rate", "measurement", "", true},
		{"gas_usage_average_lph", "Gasdebiet gemiddeld", "L/h", "volume_flow_rate", "measurement", "", true},
		{"burner_starts", "Aantal branderstarts", "", "", "total_increasing", "diagnostic", false},
		{"burner_hours", "Branderuren", "h", "duration", "total_increasing", "diagnostic", false},
		{"ch_pump_hours", "Cv-pompuren", "h", "duration", "total_increasing", "diagnostic", false},
		{"dhw_pump_hours", "Tapwaterpompuren", "h", "duration", "total_increasing", "diagnostic", false},
		{"dhw_burner_hours", "Tapwaterbranderuren", "h", "duration", "total_increasing", "diagnostic", false},
		{"max_boiler_capacity_kw", "Ketelcapaciteit", "kW", "power", "measurement", "diagnostic", false},
		{"min_modulation_level_percent", "Minimaal modulatieniveau", "%", "", "measurement", "diagnostic", false},
		{"opentherm_slave_version", "OpenTherm ketelversie", "", "", "", "diagnostic", false},
		{"opentherm_oem_diagnostic_code", "OpenTherm diagnosecode", "", "", "", "diagnostic", false},
		{"thermostat_connection", "Thermostaatverbinding (ruw)", "", "", "", "diagnostic", false},
		{"error_code", "Thermostaat foutcode (ruw)", "", "", "", "diagnostic", false},
		{"heating_type", "Verwarmingstype (ruw)", "", "", "", "diagnostic", false},
		{"heater_fuel_type", "Brandstoftype", "", "", "", "diagnostic", false},
	}
	for _, s := range sensors {
		cfg := map[string]any{
			"name": s.name, "unique_id": "toon_local_" + s.id, "device": dev,
			"state_topic": base + "/state/" + s.id, "availability_topic": base + "/availability",
		}
		if s.unit != "" {
			cfg["unit_of_measurement"] = s.unit
		}
		if s.class != "" {
			cfg["device_class"] = s.class
		}
		if s.stateClass != "" {
			cfg["state_class"] = s.stateClass
		}
		if s.category != "" {
			cfg["entity_category"] = s.category
			cfg["enabled_by_default"] = s.enabledByDefault
		}
		entities = append(entities, entity{"sensor", s.id, cfg})
	}
	binarySensors := []struct {
		id, name, class, category string
	}{
		{"burner_active", "Brander actief", "heat", ""},
		{"dhw_active", "Tapwater actief", "running", ""},
		{"opentherm_communication_error", "OpenTherm communicatiefout", "problem", "diagnostic"},
	}
	for _, b := range binarySensors {
		cfg := map[string]any{
			"name": b.name, "unique_id": "toon_local_" + b.id, "device": dev,
			"state_topic": base + "/state/" + b.id, "availability_topic": base + "/availability",
			"payload_on": "1", "payload_off": "0",
		}
		if b.class != "" {
			cfg["device_class"] = b.class
		}
		if b.category != "" {
			cfg["entity_category"] = b.category
		}
		entities = append(entities, entity{"binary_sensor", b.id, cfg})
	}
	numbers := []struct {
		id, name, unit string
		min, max, step float64
	}{
		{"dhw_setpoint", "Tapwatertemperatuur", "°C", 30, 65, 1},
		{"max_heater_temperature", "Maximale cv-temperatuur", "°C", 30, 90, 1},
		{"max_heating_rate", "Maximaal cv-vermogen", "kW", 1, 40, 0.5},
		{"temperature_offset", "Temperatuurcorrectie", "°C", -5, 5, 0.1},
	}
	for _, n := range numbers {
		entities = append(entities, entity{"number", n.id, map[string]any{
			"name": n.name, "unique_id": "toon_local_" + n.id, "device": dev,
			"state_topic": base + "/state/" + n.id, "command_topic": base + "/set/" + n.id,
			"availability_topic": base + "/availability", "unit_of_measurement": n.unit,
			"min": n.min, "max": n.max, "step": n.step, "mode": "box",
		}})
	}
	injected := []struct {
		id, name, unit, class string
		min, max, step        float64
	}{
		{"power_w", "Injectie huidig verbruik", "W", "power", 0, 100000, 1},
		{"production_w", "Injectie huidige teruglevering", "W", "power", 0, 100000, 1},
		{"import_low_kwh", "Injectie verbruik laag tarief", "kWh", "energy", 0, 100000000, 0.001},
		{"import_high_kwh", "Injectie verbruik hoog tarief", "kWh", "energy", 0, 100000000, 0.001},
		{"export_low_kwh", "Injectie teruglevering laag tarief", "kWh", "energy", 0, 100000000, 0.001},
		{"export_high_kwh", "Injectie teruglevering hoog tarief", "kWh", "energy", 0, 100000000, 0.001},
		{"gas_total_m3", "Injectie gasmeterstand", "m³", "", 0, 10000000, 0.001},
	}
	for _, n := range injected {
		cfg := map[string]any{
			"name": n.name, "unique_id": "toon_local_inject_" + n.id, "device": dev,
			"state_topic": base + "/state/injected/" + n.id, "command_topic": base + "/inject/" + n.id,
			"availability_topic": base + "/availability", "unit_of_measurement": n.unit,
			"min": n.min, "max": n.max, "step": n.step, "mode": "box",
		}
		if n.class != "" {
			cfg["device_class"] = n.class
		}
		entities = append(entities, entity{"number", "inject_" + n.id, cfg})
	}
	// Home Assistant MQTT Discovery is not a generic cross-platform discovery
	// protocol. Domoticz needs installation-specific idx values and openHAB
	// normally uses explicitly configured MQTT channels, so those profiles keep
	// the stable standard MQTT topic contract without publishing misleading HA
	// discovery records.
	discoveryEnabled := c.Discovery && c.Platform == "homeassistant"
	for _, e := range entities {
		topic := prefix + "/" + e.component + "/toon_local/" + e.id + "/config"
		entityEnabled := discoveryEnabled
		if strings.HasPrefix(e.id, "inject_") && !c.EnergyInjection {
			entityEnabled = false
		}
		if !entityEnabled {
			if err := m.publish(topic, nil, true); err != nil {
				return err
			}
			continue
		}
		e.cfg["origin"] = map[string]any{"name": "Toon MQTT lokaal", "sw_version": version}
		b, _ := json.Marshal(e.cfg)
		if err := m.publish(topic, b, true); err != nil {
			return err
		}
	}
	return nil
}

func boundedFloat(payload string, min, max float64) (float64, error) {
	v, err := strconv.ParseFloat(strings.TrimSpace(payload), 64)
	if err != nil || math.IsNaN(v) || math.IsInf(v, 0) || v < min || v > max {
		return 0, fmt.Errorf("waarde moet tussen %.1f en %.1f liggen", min, max)
	}
	return v, nil
}

type energyRoute struct {
	uuid, service, variable string
	max, multiplier         float64
	total                   bool
}

var energyRoutes = map[string]energyRoute{
	"power_w": {
		uuid: "063e990e-b2e1-48a0-8c77-6d0b8c8cd098", service: "ElectricityFlowMeter",
		variable: "CurrentElectricityFlow", max: 100000, multiplier: 1,
	},
	"production_w": {
		uuid: "ce64d6ee-cb30-405f-ae14-337abcf9ffd9", service: "ElectricityFlowMeter",
		variable: "CurrentElectricityFlow", max: 100000, multiplier: 1,
	},
	"import_low_kwh": {
		uuid: "22e94ca9-35bf-443c-aa45-ed540403a53a", service: "ElectricityQuantityMeter",
		variable: "CurrentElectricityQuantity", max: 100000000, multiplier: 1000, total: true,
	},
	"import_high_kwh": {
		uuid: "063e990e-b2e1-48a0-8c77-6d0b8c8cd098", service: "ElectricityQuantityMeter",
		variable: "CurrentElectricityQuantity", max: 100000000, multiplier: 1000, total: true,
	},
	"export_low_kwh": {
		uuid: "695e3d86-9797-44f1-bf1e-1e30fcf58e58", service: "ElectricityQuantityMeter",
		variable: "CurrentElectricityQuantity", max: 100000000, multiplier: 1000, total: true,
	},
	"export_high_kwh": {
		uuid: "ce64d6ee-cb30-405f-ae14-337abcf9ffd9", service: "ElectricityQuantityMeter",
		variable: "CurrentElectricityQuantity", max: 100000000, multiplier: 1000, total: true,
	},
	"gas_total_m3": {
		uuid: "f925ac94-fa10-488e-a902-7d880ca205cc", service: "GasQuantityMeter",
		variable: "CurrentGasQuantity", max: 10000000, multiplier: 1000, total: true,
	},
}

func energyValue(state *EnergyState, name string) *float64 {
	switch name {
	case "power_w":
		return state.PowerW
	case "production_w":
		return state.ProductionW
	case "import_low_kwh":
		return state.ImportLowKWh
	case "import_high_kwh":
		return state.ImportHighKWh
	case "export_low_kwh":
		return state.ExportLowKWh
	case "export_high_kwh":
		return state.ExportHighKWh
	case "gas_total_m3":
		return state.GasTotalM3
	}
	return nil
}

func setEnergyValue(state *EnergyState, name string, value float64) {
	v := value
	switch name {
	case "power_w":
		state.PowerW = &v
	case "production_w":
		state.ProductionW = &v
	case "import_low_kwh":
		state.ImportLowKWh = &v
	case "import_high_kwh":
		state.ImportHighKWh = &v
	case "export_low_kwh":
		state.ExportLowKWh = &v
	case "export_high_kwh":
		state.ExportHighKWh = &v
	case "gas_total_m3":
		state.GasTotalM3 = &v
	}
}

func sendMeterNotify(route energyRoute, value float64) error {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	wireValue := strconv.FormatFloat(value*route.multiplier, 'f', 0, 64)
	out, err := exec.CommandContext(
		ctx, "/qmf/bin/bxt", "-N", "-u", route.uuid, "-s", route.service,
		"-a", route.variable, "-v", wireValue, "-w", "0", "-c",
	).CombinedOutput()
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil {
		return fmt.Errorf("BoxTalk meterinjectie: %v (%s)", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func applyEnergyValue(m *mqttClient, c Config, state *EnergyState, name, payload string) error {
	route, ok := energyRoutes[name]
	if !ok {
		return fmt.Errorf("onbekende energiewaarde: %s", name)
	}
	value, err := boundedFloat(payload, 0, route.max)
	if err != nil {
		return err
	}
	if previous := energyValue(state, name); route.total && previous != nil && value+0.0000001 < *previous {
		return fmt.Errorf("%s mag niet teruglopen (reset eerst de tellerbeveiliging)", name)
	}
	if err := sendMeterNotify(route, value); err != nil {
		return err
	}
	setEnergyValue(state, name, value)
	state.LastUpdate = time.Now().Format(time.RFC3339)
	saveEnergyState(*state)
	return m.publish(c.BaseTopic+"/state/injected/"+name, []byte(strconv.FormatFloat(value, 'f', -1, 64)), true)
}

func applyEnergyJSON(m *mqttClient, c Config, state *EnergyState, payload string) error {
	var values map[string]json.RawMessage
	if err := json.Unmarshal([]byte(payload), &values); err != nil {
		return errors.New("energie-state is geen geldige JSON")
	}
	applied := 0
	for name := range energyRoutes {
		raw, ok := values[name]
		if !ok {
			continue
		}
		var value float64
		if err := json.Unmarshal(raw, &value); err != nil {
			return fmt.Errorf("%s moet een getal zijn", name)
		}
		if err := applyEnergyValue(m, c, state, name, strconv.FormatFloat(value, 'f', -1, 64)); err != nil {
			return err
		}
		applied++
	}
	if applied == 0 {
		return errors.New("energie-state bevat geen ondersteunde waarden")
	}
	return nil
}

func handleEnergyCommand(m *mqttClient, c Config, state *EnergyState, topic, payload string) error {
	if !c.EnergyInjection {
		return errors.New("energie-injectie is uitgeschakeld")
	}
	name := strings.TrimPrefix(topic, c.BaseTopic+"/inject/")
	if name == "state" {
		return applyEnergyJSON(m, c, state, payload)
	}
	return applyEnergyValue(m, c, state, name, payload)
}

func publishInjectedState(m *mqttClient, c Config, state EnergyState) error {
	for name := range energyRoutes {
		value := energyValue(&state, name)
		if value == nil {
			continue
		}
		if err := m.publish(
			c.BaseTopic+"/state/injected/"+name,
			[]byte(strconv.FormatFloat(*value, 'f', -1, 64)),
			true,
		); err != nil {
			return err
		}
	}
	return nil
}

func invokeOK(out string, err error) error {
	if err != nil {
		return err
	}
	if strings.Contains(out, `class="error"`) || strings.Contains(strings.ToLower(out), "errorresponse") {
		return errors.New("Toon weigerde het commando")
	}
	return nil
}

func handleCommand(c Config, topic, payload string) error {
	if !c.ControlEnabled {
		return errors.New("bediening is uitgeschakeld")
	}
	name := strings.TrimPrefix(topic, c.BaseTopic+"/set/")
	payload = strings.TrimSpace(payload)
	switch name {
	case "setpoint":
		v, err := boundedFloat(payload, 6, 30)
		if err != nil {
			return err
		}
		var th ThermostatInfo
		if err := readJSON("http://127.0.0.1/happ_thermstat?action=getThermostatInfo", &th); err != nil {
			return err
		}
		state := "2"
		if th.ProgramState == "0" {
			state = "0"
		}
		out, err := invokeBXT("", "ChangeSchemeState", "state", state, "temperature", strconv.Itoa(int(math.Round(v*100))))
		return invokeOK(out, err)
	case "preset":
		states := map[string]string{"comfort": "0", "home": "1", "sleep": "2", "away": "3"}
		tempState, ok := states[strings.ToLower(payload)]
		if !ok {
			return errors.New("preset is comfort, home, sleep of away")
		}
		var th ThermostatInfo
		if err := readJSON("http://127.0.0.1/happ_thermstat?action=getThermostatInfo", &th); err != nil {
			return err
		}
		state := "2"
		if th.ProgramState == "0" {
			state = "0"
		}
		out, err := invokeBXT("", "ChangeSchemeState", "state", state, "temperatureState", tempState)
		return invokeOK(out, err)
	case "program":
		v := strings.ToLower(payload)
		state := ""
		if v == "schedule" || v == "on" || v == "1" || v == "auto" {
			state = "1"
		} else if v == "manual" || v == "off" || v == "0" {
			state = "0"
		} else {
			return errors.New("programma is schedule of manual")
		}
		out, err := invokeBXT("", "ChangeSchemeState", "state", state)
		return invokeOK(out, err)
	case "dhw_enabled", "dhw_setpoint":
		out, err := runBXT("Thermostat", "GetDhwSettings")
		if err != nil {
			return err
		}
		enabled, setpoint := xmlValue(out, "dhwEnabled"), xmlValue(out, "dhwSetpoint")
		if name == "dhw_enabled" {
			v := strings.ToLower(payload)
			if v == "1" || v == "on" || v == "true" {
				enabled = "1"
			} else if v == "0" || v == "off" || v == "false" {
				enabled = "0"
			} else {
				return errors.New("dhw_enabled is 0 of 1")
			}
		} else {
			v, e := boundedFloat(payload, 30, 65)
			if e != nil {
				return e
			}
			setpoint = strconv.FormatFloat(v, 'f', 0, 64)
		}
		out, err = invokeBXT("Thermostat", "SetDhwSettings", "dhwEnabled", enabled, "dhwSetpoint", setpoint)
		return invokeOK(out, err)
	case "max_heater_temperature", "max_heating_rate":
		out, err := runBXT("Thermostat", "GetChSettings")
		if err != nil {
			return err
		}
		heatType := xmlValue(out, "heatingType")
		maxTemp := xmlValue(out, "maxHeaterTemp")
		rate := xmlValue(out, "maxHeatingRate")
		if name == "max_heater_temperature" {
			v, e := boundedFloat(payload, 30, 90)
			if e != nil {
				return e
			}
			maxTemp = strconv.FormatFloat(v, 'f', 0, 64)
		} else {
			v, e := boundedFloat(payload, 1, 40)
			if e != nil {
				return e
			}
			rate = strconv.FormatFloat(v, 'f', 1, 64)
		}
		out, err = invokeBXT("Thermostat", "SetChSettings", "heatingType", heatType, "maxHeaterTemp", maxTemp, "maxHeatingRate", rate)
		return invokeOK(out, err)
	case "temperature_offset":
		v, err := boundedFloat(payload, -5, 5)
		if err != nil {
			return err
		}
		out, err := invokeBXT("Thermostat", "AdjustTempOffset", "offset", strconv.FormatFloat(v, 'f', 1, 64))
		return invokeOK(out, err)
	default:
		return fmt.Errorf("onbekend commando: %s", name)
	}
}

func cleanupAfterAppRemoval() {
	for _, path := range []string{
		"/qmf/bin/toon_mqtt_client",
		"/qmf/bin/toon-mqtt-service.sh",
		"/etc/rc5.d/S99toon-mqtt",
		"/var/run/toon-mqtt.pid",
		"/var/run/toon-mqtt.pid.stopped",
		"/var/volatile/log/toon-mqtt.log",
		configPath,
		energyStatePath,
		statusPath,
		controlPath,
	} {
		_ = os.Remove(path)
	}
	_ = os.RemoveAll(backupPath)
}

// watchAppRemoval is deliberately independent of the MQTT connection. An
// uninstall must also clean up the service when the broker is unavailable or
// has never been configured. Requiring the app path to be absent for five
// consecutive seconds avoids reacting to the brief remove/relink window during
// a Store upgrade.
func watchPathRemoval(path string, grace, pollInterval time.Duration, onRemoval func()) {
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	var missingSince time.Time
	for range ticker.C {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			if missingSince.IsZero() {
				missingSince = time.Now()
				continue
			}
			if time.Since(missingSince) >= grace {
				onRemoval()
				return
			}
			continue
		}
		missingSince = time.Time{}
	}
}

func watchAppRemoval() {
	watchPathRemoval(appPath, 5*time.Second, time.Second, func() {
		// Live flows must not remain visible on Toon after the bridge has gone.
		_ = sendMeterNotify(energyRoutes["power_w"], 0)
		_ = sendMeterNotify(energyRoutes["production_w"], 0)
		cleanupAfterAppRemoval()
		os.Exit(0)
	})
}

func runConnected(m *mqttClient, c Config) error {
	defer m.conn.Close()
	if err := m.subscribe(c.BaseTopic + "/set/#"); err != nil {
		return err
	}
	if err := m.subscribe(c.BaseTopic + "/inject/#"); err != nil {
		return err
	}
	homeAssistantStatusTopic := c.DiscoveryPrefix + "/status"
	if c.Platform == "homeassistant" && c.Discovery {
		if err := m.subscribe(homeAssistantStatusTopic); err != nil {
			return err
		}
	}
	if err := m.publish(c.BaseTopic+"/availability", []byte("online"), true); err != nil {
		return err
	}
	if err := publishDiscovery(m, c); err != nil {
		return err
	}
	status := Status{Connected: true, Broker: net.JoinHostPort(c.Host, strconv.Itoa(c.Port))}
	energyState := loadEnergyState()
	status.LastEnergy = energyState.LastUpdate
	if err := publishInjectedState(m, c, energyState); err != nil {
		return err
	}
	messages := make(chan mqttMessage, 20)
	errs := make(chan error, 1)
	go m.reader(messages, errs)
	ticker := time.NewTicker(time.Duration(c.IntervalSeconds) * time.Second)
	defer ticker.Stop()
	ping := time.NewTicker(20 * time.Second)
	defer ping.Stop()
	controlTicker := time.NewTicker(time.Second)
	defer controlTicker.Stop()
	energyTicker := time.NewTicker(10 * time.Second)
	defer energyTicker.Stop()
	energyZeroed := false
	publish := func() error {
		t := collectTelemetry()
		if err := publishState(m, c, t); err != nil {
			return err
		}
		status.LastPublish = t.Timestamp
		if parsed, err := time.Parse(time.RFC3339, energyState.LastUpdate); err == nil {
			status.EnergyOnline = time.Since(parsed) <= time.Duration(c.EnergyTimeout)*time.Second
		}
		status.LastEnergy = energyState.LastUpdate
		status.LastError = ""
		writeStatus(status)
		return nil
	}
	if err := publish(); err != nil {
		return err
	}
	for {
		select {
		case <-ticker.C:
			if err := publish(); err != nil {
				return err
			}
		case <-ping.C:
			if err := m.write(packet(0xC0, nil)); err != nil {
				return err
			}
		case <-controlTicker.C:
			command, err := os.ReadFile(controlPath)
			if err != nil {
				continue
			}
			_ = os.Remove(controlPath)
			switch strings.TrimSpace(string(command)) {
			case "reload":
				return errReload
			case "test":
				status.LastTest = time.Now().Format(time.RFC3339)
				if err := m.publish(c.BaseTopic+"/test", []byte("Toon MQTT verbinding geslaagd"), false); err != nil {
					status.TestResult = "Mislukt: " + err.Error()
					status.LastError = err.Error()
				} else {
					status.TestResult = "Verbinding geslaagd"
					status.LastError = ""
				}
				writeStatus(status)
			case "reset_energy":
				energyState = EnergyState{}
				saveEnergyState(energyState)
				status.EnergyOnline = false
				status.LastEnergy = ""
				status.TestResult = "Tellerbeveiliging gereset"
				writeStatus(status)
			}
		case <-energyTicker.C:
			parsed, err := time.Parse(time.RFC3339, energyState.LastUpdate)
			stale := err != nil || time.Since(parsed) > time.Duration(c.EnergyTimeout)*time.Second
			status.EnergyOnline = !stale
			status.LastEnergy = energyState.LastUpdate
			if stale && !energyZeroed && c.EnergyInjection {
				_ = sendMeterNotify(energyRoutes["power_w"], 0)
				_ = sendMeterNotify(energyRoutes["production_w"], 0)
				energyZeroed = true
			}
			writeStatus(status)
		case msg := <-messages:
			if msg.topic == homeAssistantStatusTopic {
				if strings.EqualFold(strings.TrimSpace(string(msg.payload)), "online") {
					if err := publishDiscovery(m, c); err != nil {
						return err
					}
					if err := publishInjectedState(m, c, energyState); err != nil {
						return err
					}
					if err := publish(); err != nil {
						return err
					}
				}
				continue
			}
			var err error
			if strings.HasPrefix(msg.topic, c.BaseTopic+"/inject/") {
				err = handleEnergyCommand(m, c, &energyState, msg.topic, string(msg.payload))
				if err == nil {
					energyZeroed = false
					status.EnergyOnline = true
					status.LastEnergy = energyState.LastUpdate
				}
			} else {
				err = handleCommand(c, msg.topic, string(msg.payload))
			}
			result := map[string]any{"topic": msg.topic, "payload": string(msg.payload), "ok": err == nil, "timestamp": time.Now().Format(time.RFC3339)}
			if err != nil {
				result["error"] = err.Error()
				status.LastError = err.Error()
			} else {
				status.LastError = ""
			}
			status.LastCommand = msg.topic
			b, _ := json.Marshal(result)
			resultTopic := c.BaseTopic + "/command_result"
			if strings.HasPrefix(msg.topic, c.BaseTopic+"/inject/") {
				resultTopic = c.BaseTopic + "/inject_result"
			}
			_ = m.publish(resultTopic, b, false)
			writeStatus(status)
			if err == nil {
				time.Sleep(750 * time.Millisecond)
				if err := publish(); err != nil {
					return err
				}
			}
		case err := <-errs:
			return err
		}
	}
}

func probe(c Config) error {
	m, err := connectMQTT(c, false)
	if err != nil {
		return err
	}
	defer m.conn.Close()
	if err := m.publish(c.BaseTopic+"/test", []byte("Toon MQTT verbinding geslaagd"), false); err != nil {
		return err
	}
	return m.write(packet(0xE0, nil))
}

func publishCLI(c Config, topic, payload string) error {
	m, err := connectMQTT(c, false)
	if err != nil {
		return err
	}
	defer m.conn.Close()
	if err := m.publish(topic, []byte(payload), false); err != nil {
		return err
	}
	return m.write(packet(0xE0, nil))
}

func dumpOne(c Config, topic string) error {
	m, err := connectMQTT(c, false)
	if err != nil {
		return err
	}
	defer m.conn.Close()
	if err := m.subscribe(topic); err != nil {
		return err
	}
	_ = m.conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	for {
		h, p, err := m.readPacket()
		if err != nil {
			return err
		}
		if h>>4 != 3 || len(p) < 2 {
			continue
		}
		n := int(binary.BigEndian.Uint16(p[:2]))
		if n+2 > len(p) {
			continue
		}
		offset := n + 2
		if ((h >> 1) & 3) > 0 {
			offset += 2
		}
		if offset <= len(p) {
			fmt.Printf("%s %s\n", string(p[2:2+n]), string(p[offset:]))
			_ = m.write(packet(0xE0, nil))
			return nil
		}
	}
}

func main() {
	path := configPath
	probeOnly := false
	dumpTopic := ""
	publishTopic := ""
	publishPayload := ""
	for i := 1; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "-config":
			if i+1 < len(os.Args) {
				i++
				path = os.Args[i]
			}
		case "-probe":
			probeOnly = true
		case "-dump":
			if i+1 < len(os.Args) {
				i++
				dumpTopic = os.Args[i]
			}
		case "-publish":
			if i+2 < len(os.Args) {
				publishTopic = os.Args[i+1]
				publishPayload = os.Args[i+2]
				i += 2
			}
		case "-version":
			fmt.Println(version)
			return
		}
	}
	c, err := loadConfig(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if probeOnly {
		if err := probe(c); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("MQTT verbinding geslaagd")
		return
	}
	if publishTopic != "" {
		if err := publishCLI(c, publishTopic, publishPayload); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	if dumpTopic != "" {
		if err := dumpOne(c, dumpTopic); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	go watchAppRemoval()
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stop
		os.Exit(0)
	}()
	for {
		m, err := connectMQTT(c, true)
		if err == nil {
			err = runConnected(m, c)
		}
		if errors.Is(err, errReload) {
			if fresh, e := loadConfig(path); e == nil {
				c = fresh
			}
			continue
		}
		s := Status{Connected: false, Broker: net.JoinHostPort(c.Host, strconv.Itoa(c.Port)), LastError: err.Error()}
		writeStatus(s)
		time.Sleep(5 * time.Second)
		if fresh, e := loadConfig(path); e == nil {
			c = fresh
		}
	}
}
