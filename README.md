# CloseScale_ModularEA (v1.001)

Arquitetura modular com contratos agnosticos e plugins isolados por arquivo.

## Regras de arquitetura (obrigatorias)
- Nenhum indicador pode ter logica fora do arquivo do proprio plugin em `Indicators/Plugins`.
- Nenhuma estrategia pode ter logica fora do arquivo da propria estrategia em `Strategies/Plugins`.
- `EntrySignal` nao conhece indicador especifico nem estrategia especifica.
- `Main` apenas coordena: Indicators -> EntrySignal -> OrderManager -> Exec -> View.
- `Exec` e o unico modulo que toca broker.
- Config de submodulos deve seguir cardinalidade:
  - Exclusivo (1 ativo por vez): um combobox com todas as opcoes.
  - Combinavel (0..N): um combobox de habilitar/desabilitar por submodulo.

## Estrutura
- `CloseScale_ModularEA.mq5`: coordenacao principal.
- `Contracts/`: tipos e interfaces agnosticas.
- `Config/`: inputs e resolucao de configuracao.
- `Indicators/Plugins/`: um arquivo por indicador plugin.
- `Strategies/Plugins/`: um arquivo por estrategia plugin.
- `EntrySignal/`: avaliador generico de regras.
- `OrderManager/`: apenas orquestra abertura/gestao e chama politicas (sem conversao de indicador).
- `Exec/`: executa no broker e retorna status.
- `View/`: publica em chart e terminal.
- `Generated/`: registries gerados automaticamente.
- `Tools/generate_registry.py`: gera os registries.

## Como adicionar um novo indicador (sem tocar no Main)
1. Copiar o template:
   - `Indicators/Templates/IndicatorPlugin_iCustom.Template.mqh.txt`
2. Criar um novo arquivo em `Indicators/Plugins/NomeDoPlugin.mqh`.
2. Implementar `class CIndicatorPlugin_NomeDoPlugin : public IIndicatorPlugin`.
3. Implementar factory obrigatoria:
   - `IIndicatorPlugin* CreateIndicatorPlugin_NomeDoPlugin()`
4. Rodar:
   - `Tools/generate_registry.py`
5. Recompilar o EA.

Observacao importante:
- Nao expor inputs do indicador no EA.
- O plugin deve chamar `iCustom` sem parametros extras para usar os defaults do indicador standalone.
- O plugin de indicador nao deve desenhar nada no chart/terminal.
- Toda exibicao e responsabilidade do modulo `View` (`ChartView` e `TerminalView`).

## Como adicionar uma nova estrategia (sem tocar no Main)
1. Criar novo arquivo em `Strategies/Plugins/NomeDaStrategia.mqh`.
2. Implementar `class CStrategyPlugin_NomeDaStrategia : public IStrategyPlugin`.
3. Implementar factory obrigatoria:
   - `IStrategyPlugin* CreateStrategyPlugin_NomeDaStrategia()`
4. Rodar:
   - `Tools/generate_registry.py`
5. Recompilar o EA.

## Selecao de estrategia/indicadores
- `InpModStrategyId`: id da estrategia (ou `AUTO_FIRST`).
- `InpModIndicatorsCsv`: lista CSV de ids de indicadores (ou `AUTO_ALL`).
- `InpModCheckMode`:
  - `MODULE_CHECK_DISABLED`: nao verifica.
  - `MODULE_CHECK_ON_INIT`: verifica uma vez no `OnInit`.
  - `MODULE_CHECK_ON_TIMER_ONCE`: verifica no `OnTimer` depois do delay.
- `InpModCheckDelaySec`: atraso para o modo timer.
- `InpModCheckHardFail`: se `true`, falha no `OnInit` encerra a inicializacao.
- `InpOMOnePairLock`: quando `true`, bloqueia nova entrada se ja houver posicao aberta do magic no simbolo (default atual: `false`).
- `InpAuthUseEffort`: adiciona autorizacao do modulo `EffortResultFirAuthFeed` na regra.
- `InpAuthUseMfi`: adiciona autorizacao do modulo `MfiAuthFeed` na regra.

### Regra atual da estrategia `CloseScaleEffortMfiAuth` (fase inicial)
- BUY:
  - `forecast.wave > forecast.band_up`
  - `forecast.wave > forecast.band_mid`
  - `forecast.wave > forecast.band_dn`
  - `forecast.wave > const.zero`
- SELL:
  - `forecast.wave < forecast.band_up`
  - `forecast.wave < forecast.band_mid`
  - `forecast.wave < forecast.band_dn`
  - `forecast.wave < const.zero`
- Default atual de indicadores carregados:
  - `InpModIndicatorsCsv = "CloseScaleForecastFeed"`
  - O sistema carrega exatamente os IDs informados em `InpModIndicatorsCsv`.
  - `InpAuthUseEffort`/`InpAuthUseMfi` controlam apenas a regra da estrategia.

## Politicas do Order Manager (pluggable por input)
- `InpOMSlPolicyId`: politica de SL (ex.: `CloseScaleSL_Back1Level`).
- `InpOMTpPolicyId`: politica de TP/finalizacao (ex.: `CloseScaleTP_NextLevelAndFinal`).
- `InpOMTsPolicyId`: politica de trailing (ex.: `CloseScaleTS_HalfLevel`, `ATR_TS`, `NoneTS`).
- `InpOMRiskSubmodule` (combobox exclusivo): escolhe uma unica gestao de risco ativa.
- `InpOMHedgeSubmodule` (combobox on/off): habilita/desabilita o submodulo de hedge.
- Implementacao das politicas fica em `Strategies/TradePolicies/`:
  - `SL/`
  - `TP/`
  - `TS/`
  - `Risk/`
- Para adicionar nova politica:
1. Criar o arquivo da politica no diretorio do bloco (`SL`, `TP` ou `TS`).
2. Implementar a interface correspondente (`ISlPolicyPlugin`, `ITpPolicyPlugin`, `ITsPolicyPlugin`).
3. Registrar no `Strategies/TradePolicies/TradePolicyRegistry.mqh`.
4. Selecionar o ID da politica via input no EA.

Observacao:
- Nenhuma formula de conversao de niveis/bandas fica no `OrderManager`.
- Conversao de CloseScale (escala -> preco) fica no plugin de indicador `Indicators/Plugins/CloseScaleForecastFeed.mqh`.

## Regra de Combobox por Submodulo
- Regra obrigatoria:
  - Quando o modulo permite apenas uma estrategia/politica por vez, usar um unico combobox com todas as opcoes.
  - Quando o modulo permite composicao simultanea, cada submodulo deve ter seu proprio combobox (habilitar/desabilitar).
- Aplicacao atual:
  - `Risk` e exclusivo: usar somente `InpOMRiskSubmodule` para escolher uma gestao por vez (`Default` ou `CloseScale Countertrend Above Zero`).
  - `Hedge` e submodulo opcional: usar `InpOMHedgeSubmodule` para ligar/desligar.

## Pacote atual (v1.001)
- Indicadores plugin:
  - `CloseScaleForecastFeed` (`CLOSE_Scale_v6.0-forecast`)
  - `EffortResultFirAuthFeed` (`Effort_Result_FIR`)
  - `MfiAuthFeed` (`mfi`)
- Estrategia plugin:
  - `CloseScaleEffortMfiAuth`

## Presets prontos
Diretorio: `Presets/`

- `CloseScale_ModularEA_HEDGE_OCO_STOP_Balanced.set`
  - `InpOMHedgeSubmodule=1` (HEDGE OCO v1 ligado)
  - Familia de ordens: STOP
  - Max cestas ativas: 1
- `CloseScale_ModularEA_HEDGE_OCO_STOP_LIMIT_Balanced.set`
  - `InpOMHedgeSubmodule=1` (HEDGE OCO v1 ligado)
  - Familia de ordens: STOP_LIMIT
  - Max cestas ativas: 1
- `CloseScale_ModularEA_LEGACY_CloseScale_Base.set`
  - `InpOMHedgeSubmodule=0` (hedge desligado)
  - Perfil base para comparacao com o modo hedge
