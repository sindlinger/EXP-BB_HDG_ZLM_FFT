# CloseScale_ModularEA (v1.0.0)

Arquitetura modular com contratos agnosticos e plugins isolados por arquivo.

## Regras de arquitetura (obrigatorias)
- Nenhum indicador pode ter logica fora do arquivo do proprio plugin em `Indicators/Plugins`.
- Nenhuma estrategia pode ter logica fora do arquivo da propria estrategia em `Strategies/Plugins`.
- `EntrySignal` nao conhece indicador especifico nem estrategia especifica.
- `Main` apenas coordena: Indicators -> EntrySignal -> OrderManager -> Exec -> View.
- `Exec` e o unico modulo que toca broker.

## Estrutura
- `CloseScale_ModularEA.mq5`: coordenacao principal.
- `Contracts/`: tipos e interfaces agnosticas.
- `Config/`: inputs e resolucao de configuracao.
- `Indicators/Plugins/`: um arquivo por indicador plugin.
- `Strategies/Plugins/`: um arquivo por estrategia plugin.
- `EntrySignal/`: avaliador generico de regras.
- `OrderManager/`: gera requests de ordem e aplica slots.
- `Exec/`: executa no broker e retorna status.
- `View/`: publica em chart e terminal.
- `Generated/`: registries gerados automaticamente.
- `Tools/generate_registry.py`: gera os registries.

## Como adicionar um novo indicador (sem tocar no Main)
1. Criar um novo arquivo em `Indicators/Plugins/NomeDoPlugin.mqh`.
2. Implementar `class CIndicatorPlugin_NomeDoPlugin : public IIndicatorPlugin`.
3. Implementar factory obrigatoria:
   - `IIndicatorPlugin* CreateIndicatorPlugin_NomeDoPlugin()`
4. Rodar:
   - `Tools/generate_registry.py`
5. Recompilar o EA.

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

## Slots do Order Manager
- 3 slots para cada bloco: SL, TP, TS, BE e Pending.
- Cada slot tem `None` ou estrategia correspondente.
- `OrderManager` aplica a primeira opcao nao-`None` por bloco.
