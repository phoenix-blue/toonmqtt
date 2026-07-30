package main

import (
	"math"
	"testing"
)

func closeEnough(a, b float64) bool {
	return math.Abs(a-b) < 0.001
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
