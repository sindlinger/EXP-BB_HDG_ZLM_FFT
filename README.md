# CloseScale_ModularEA (v1.001)

EA modular para MT5 com separacao estrita por dominio: indicador, estrategia, ordem, execucao, bloqueios e view.

## Objetivo da arquitetura
- Permitir evolucao por plugin sem alterar `Main`.
- Evitar hardcode cruzado entre dominios.
- Garantir rastreabilidade do sinal a partir dos buffers reais.
- Centralizar orquestracao no `Main`, mantendo modulos inertes.

## Regras obrigatorias
- Logica de indicador fica apenas em `Indicators/Plugins`.
- Logica de estrategia fica apenas em `Strategies/Plugins`.
- `Main` coordena os modulos e nao implementa regra de indicador/estrategia.
- `Exec` e o unico modulo que toca broker.
- `View` e o unico modulo que desenha/anexa no chart e escreve no terminal.
- `Indicators` e o unico modulo que usa `iCustom` e `CopyBuffer`.
- Bloqueios de entrada/execucao passam pela autoridade de bloqueio (`Policies/BlockAuthorityModule.mqh`).

## Estrutura do codigo
| Modulo | Diretorio/Arquivo | Responsabilidade |
|---|---|---|
| Bootstrap | `CloseScale_ModularEA.mq5` | `OnInit/OnTick/OnTimer/OnDeinit`, bind dos modulos, lifecycle do EA |
| Main Runtime | `Main/MainRuntimeModule.mqh` | Pipeline do tick, chamada ordenada dos modulos, montagem do estado final de view |
| Contracts | `Contracts/` | Tipos compartilhados (`CoreTypes`), interfaces de plugin (`Interfaces`), snapshot/bus (`Snapshot`) |
| Config | `Config/` | Inputs do EA, parse, validacao e montagem de objetos de configuracao |
| Indicators | `Indicators/IndicatorModule.mqh` + `Indicators/Plugins/` | Inicializa plugins de indicador e publica buffers no snapshot |
| Strategies | `Strategies/StrategyModule.mqh` + `Strategies/Plugins/` | Construcao de regra, avaliacao de sinal e estado visual da estrategia |
| Order Manager | `OrderManager/OrderManagerModule.mqh` | Gera requests de abertura/gestao, aplica politicas de SL/TP/TS/BE/Pending/Risk |
| Policies | `Policies/BlockAuthorityModule.mqh` | Autoridade unica para gate de run/open/manage e cooldowns |
| Exec | `Exec/ExecModule.mqh` | Envio/modificacao/fechamento de ordens via `CTrade`, com retorno procedural |
| Verification | `Verification/VerificationModule.mqh` | Module-check em init/timer e status de prontidao dos modulos |
| View | `View/ViewModule.mqh`, `View/ChartView.mqh`, `View/TerminalView.mqh` | Painel de chart, logs, attach/detach de indicadores |
| Registries | `Generated/*.generated.mqh` | Descoberta de plugins por ID (indicadores e estrategias) |
| Tools | `Tools/generate_registry.py` | Geracao automatica dos registries |
| Native Bus | `Native/CSM_Bus/` | DLL de snapshot (`CSM_Bus.dll`) para publish/read/report entre modulos |

## Fluxo de execucao
### OnInit
1. Carrega e valida inputs (`Config`).
2. Sobe `View`.
3. Inicializa `Snapshot` + DLL bus (`CsmBus_Init`).
4. Inicializa `Strategy` e constroi regra.
5. Inicializa `Indicators` pelos IDs selecionados.
6. Anexa indicadores no chart apenas via `View` (quando habilitado).
7. Inicializa `OrderManager` e `Exec`.
8. Configura `Verification` e roda module-check conforme modo.
9. Faz `Bind` do runtime (`Main`).

### OnTick
1. `Main` abre ciclo do snapshot (`BeginCycle`).
2. `Indicators.Update` publica os buffers no snapshot.
3. `Strategy.EvaluateSignal` avalia regra usando snapshot.
4. `Strategy.ApplyDecisionSnapshot` grava bias/trigger no snapshot.
5. `BlockAuthority` decide gate de `manage` e `open`.
6. `OrderManager` gera requests.
7. `Exec` executa requests e devolve status.
8. `Main` monta `SRuntimeViewState`.
9. `View.Publish` atualiza painel/log.
10. `Main` encerra ciclo (`EndCycle`).

## Contratos de dados (snapshot)
- Publicacao: `snapshot.Upsert(key, curr, prev, valid)`.
- Leitura: `snapshot.Get(key, curr, prev)`.
- O `Get` prioriza cache local do tick atual e usa bus como fallback.
- Bus DLL:
  - `CsmBus_Init`
  - `CsmBus_BeginTick`
  - `CsmBus_Publish`
  - `CsmBus_Read`
  - `CsmBus_Report`
  - `CsmBus_EndTick`

## Regra base atual da estrategia `CloseScaleEffortMfiAuth`
- BUY: `(ind1_buf0_prev <= ind1_buf2_prev) && (ind1_buf0 > ind1_buf2)`
- SELL: `(ind1_buf0_prev >= ind1_buf4_prev) && (ind1_buf0 < ind1_buf4)`

## Mapeamento de buffers do CloseScale (bridge)
- `ind1_buf0`: Feed1 (wave)
- `ind1_buf1`: Feed2
- `ind1_buf2`: BB Upper
- `ind1_buf3`: BB Middle
- `ind1_buf4`: BB Lower
- `ind1_buf5`: Zero

Fonte do bridge:
- `IndicatorsPack-2026\\EA_Bridges\\CloseScale\\CloseScale_v6_Bridge`

## Inputs principais
### Modulo
- `InpModStrategyId`
- `InpModIndicatorsCsv`
- `InpModCheckMode`
- `InpModCheckDelaySec`
- `InpModCheckHardFail`

### View
- `InpViewChart`
- `InpViewTerminal`
- `InpViewAttachIndicators`
- `InpViewAttachSubwindow1..8`

### Order Manager
- `InpOMSlPolicyId`
- `InpOMTpPolicyId`
- `InpOMTsPolicyId`
- `InpOMBePolicyId`
- `InpOMPendingPolicyId`
- `InpOMRiskSubmodule`
- `InpOMHedgeSubmodule`

### Bus
- `InpBusSession`

## Extensibilidade
### Adicionar indicador plugin
1. Criar `Indicators/Plugins/NomeDoPlugin.mqh`.
2. Implementar `IIndicatorPlugin`.
3. Implementar factory `CreateIndicatorPlugin_NomeDoPlugin()`.
4. Rodar `Tools/generate_registry.py`.
5. Recompilar.

Regras do plugin de indicador:
- Sem desenho em chart/terminal.
- Sem logica de estrategia.
- Pode usar `iCustom/CopyBuffer` somente dentro do plugin.

### Adicionar estrategia plugin
1. Criar `Strategies/Plugins/NomeDaStrategia.mqh`.
2. Implementar `IStrategyPlugin`.
3. Implementar factory `CreateStrategyPlugin_NomeDaStrategia()`.
4. Rodar `Tools/generate_registry.py`.
5. Recompilar.

Regras do plugin de estrategia:
- Somente regra de entrada/saida e estado visual da propria estrategia.
- Sem acesso direto a broker.
- Sem attach de indicador no chart.

### Adicionar politica de ordem
1. Criar plugin em `Strategies/TradePolicies/SL|TP|TS|BE|Pending|Risk`.
2. Registrar em `Strategies/TradePolicies/TradePolicyRegistry.mqh`.
3. Selecionar pelo input correspondente.

## Module-check e diagnostico
- O module-check valida coerencia minima entre regra e chaves do snapshot.
- Falha estrutural de indicador/estrategia gera erro explicito.
- Painel mostra:
  - regra textual buy/sell
  - pares `curr/prev` dos buffers usados
  - estado de trigger por lado
  - motivo do sinal e motivo de bloqueio

## Build
Compilar EA:
```bash
cmdmt compile CloseScale_ModularEA.mq5
```

Build da DLL:
```bat
Native\CSM_Bus\build_msvc.bat
```

Copiar DLL para:
`MQL5/Libraries/CSM_Bus.dll`

## Presets
Diretorio: `Presets/`
- `CloseScale_ModularEA_HEDGE_OCO_STOP_Balanced.set`
- `CloseScale_ModularEA_HEDGE_OCO_STOP_LIMIT_Balanced.set`
- `CloseScale_ModularEA_LEGACY_CloseScale_Base.set`

## Estado atual da arquitetura (v1.001)
- `EntrySignal` foi removido como modulo separado.
- A avaliacao do sinal esta dentro de `StrategyModule` + plugin da estrategia.
- Fluxo oficial: `Indicators -> Strategies -> OrderManager -> Exec -> View`.

