# MQTT-topics

In onderstaande voorbeelden is het neutrale basistopic `toon/voorbeeld`. Alle
state-topics worden retained gepubliceerd. `availability` bevat `online`
zolang de service met de broker is verbonden.

## Status en meetwaarden

| Topic achter het basistopic | Eenheid / waarde |
| --- | --- |
| `availability` | `online` of `offline` |
| `state` | Alle beschikbare telemetrie als JSON |
| `state/current_temperature` | °C |
| `state/temperature` | °C, alias voor losse discovery-sensor |
| `state/setpoint` | °C |
| `state/internal_boiler_setpoint` | °C |
| `state/program` | `schedule` of `manual` |
| `state/preset` | `comfort`, `home`, `sleep`, `away`, `holiday` of `manual` |
| `state/burner` | `off`, `heating`, `hot_water` of `preheat` |
| `state/burner_active` | `0` of `1` |
| `state/dhw_active` | `0` of `1` |
| `state/hvac_action` | `idle` of `heating` |
| `state/modulation_percent` | % |
| `state/humidity` | % relatieve luchtvochtigheid |
| `state/primary_temperature` | °C, ruwe binnenklimaatsensor |
| `state/primary_humidity` | %, ruwe binnenklimaatsensor |
| `state/tvoc_ppb` | ppb, indien aanwezig |
| `state/eco2_ppm` | ppm, indien aanwezig |
| `state/light_intensity` | ruwe telling van de omgevingslichtsensor |
| `state/power_usage_w` | W |
| `state/power_usage_average_w` | W |
| `state/power_production_w` | W |
| `state/power_production_average_w` | W |
| `state/gas_usage_lph` | liter/uur |
| `state/gas_usage_average_lph` | liter/uur |
| `state/dhw_enabled` | `0` of `1` |
| `state/dhw_setpoint` | °C |
| `state/max_heater_temperature` | °C |
| `state/max_heating_rate` | kW |
| `state/temperature_offset` | °C |
| `state/system_cpu_percent` | CPU-belasting in % |
| `state/system_load_1m` | gemiddelde systeembelasting over 1 minuut |
| `state/system_memory_percent` | geheugengebruik in % |
| `state/system_memory_available_mb` | beschikbaar geheugen in MB |
| `state/system_temperature_c` | processortemperatuur in °C |
| `state/system_uptime_hours` | uptime in uur |
| `state/system_root_storage_percent` | opslaggebruik van het systeem in % |
| `state/system_data_storage_percent` | opslaggebruik van `/mnt/data` in % |
| `state/system_wifi_received_mb` | ontvangen WiFi-data in MB |
| `state/system_wifi_transmitted_mb` | verzonden WiFi-data in MB |

Een los state-topic wordt alleen gepubliceerd wanneer de betreffende waarde op
dit Toon-model beschikbaar is én het leesvinkje aanstaat. Uitgeschakelde
retained state-topics worden leeggemaakt, zodat een domoticasysteem geen oude
waarde blijft tonen. Het JSON-bericht op `state` wordt met dezelfde keuzes
gefilterd.

De service meet volgens het ingestelde meetinterval, maar publiceert losse
state-topics alleen wanneer hun waarde verandert. Na het ingestelde
heartbeatinterval wordt altijd een volledige set verstuurd. Wanneer een
basistopic, discovery-prefix, broker of integratieprofiel via de tegel wordt
gewijzigd, ruimt de nog verbonden client eerst de oude retained state- en
Discovery-records op.

## Gebeurtenissen

Niet-retained gebeurtenissen verschijnen als JSON op `event` en daarnaast op
`event/<type>`. Voorbeelden zijn:

- `mqtt_verbonden`;
- `datapunt_beschikbaar` en `datapunt_onbeschikbaar`;
- `bronconflict` en `bronconflict_opgelost`;
- `energiedata_verouderd` en `energiedata_hersteld`;
- OpenTherm-, thermostaat-, temperatuur-, geheugen-, CPU- en opslagwaarschuwingen.

Een event bevat uitsluitend type, ernst, vaste melding, tijdstip en eventueel
de stabiele technische punt-ID. Brokergegevens en MQTT-inloggegevens worden
niet opgenomen.

Optionele OpenTherm-topics omvatten
`boiler_flow_temperature`, `boiler_return_temperature`,
`boiler_pressure_bar`, `dhw_temperature`, `dhw_flow_rate_lpm`,
`outside_temperature`, `boiler_exhaust_temperature`, ketelcapaciteit,
minimale modulatie, starts/bedrijfsuren, diagnosecode en slaveversie. Zie
[`SENSORS_AND_CONTROL.md`](SENSORS_AND_CONTROL.md) voor de beschikbaarheidsregel.

## Toon bedienen

Publiceer naar:

| Topic | Geldige payload |
| --- | --- |
| `set/setpoint` | 6 t/m 30 °C |
| `set/preset` | `comfort`, `home`, `sleep` of `away` |
| `set/program` | `schedule` of `manual` |
| `set/dhw_enabled` | `0`/`1`, `off`/`on` of `false`/`true` |
| `set/dhw_setpoint` | 30 t/m 65 °C |
| `set/max_heater_temperature` | 30 t/m 90 °C |
| `set/max_heating_rate` | 1 t/m 40 kW |
| `set/temperature_offset` | -5 t/m 5 °C |

Het resultaat verschijnt als JSON op `command_result`.

Een opdracht wordt alleen uitgevoerd wanneer zowel algemene bediening als het
schrijfvinkje van het betreffende datapunt is ingeschakeld. De zichtbare naam
die op Toon kan worden aangepast verandert deze technische topicnamen niet.

## Energie in Toon injecteren

| Topic | Eenheid | Betekenis |
| --- | --- | --- |
| `inject/power_w` | W | Actueel afgenomen vermogen |
| `inject/production_w` | W | Actueel teruggeleverd vermogen |
| `inject/import_low_kwh` | kWh | Cumulatief verbruik laag tarief |
| `inject/import_high_kwh` | kWh | Cumulatief verbruik hoog tarief |
| `inject/export_low_kwh` | kWh | Cumulatieve teruglevering laag tarief |
| `inject/export_high_kwh` | kWh | Cumulatieve teruglevering hoog tarief |
| `inject/gas_total_m3` | m3 | Cumulatieve gasmeterstand |
| `inject/state` | JSON | Een of meer van bovenstaande velden tegelijk |

Voorbeeld:

```json
{
  "power_w": 842,
  "production_w": 0,
  "import_low_kwh": 1250.123,
  "import_high_kwh": 1980.456,
  "gas_total_m3": 1345.678
}
```

Geaccepteerde waarden verschijnen retained op
`state/injected/<veldnaam>`. Het resultaat van ieder ontvangen injectiebericht
verschijnt als JSON op `inject_result`.

Tellerstanden mogen niet dalen. De beveiliging kan bewust worden gereset op de
instellingenpagina, bijvoorbeeld na vervanging van een bronmeter. Live
verbruik en productie worden, wanneer hun injectievinkje aanstaat, na de
ingestelde timeout automatisch nul.

De hoofdschakelaar **Energie-injectie** geldt voor alle injectietopics. Met de
vinkjes op dezelfde pagina kan ieder topic afzonderlijk worden toegestaan.
Uitgevinkte velden in `inject/state` worden overgeslagen; hun bestaande
Toon-waarde wordt niet gewijzigd en ook niet door de timeout op nul gezet.

Praktische bronvoorbeelden en de Home Assistant-blueprint staan in
[`ENERGY_INJECTION.md`](ENERGY_INJECTION.md).
