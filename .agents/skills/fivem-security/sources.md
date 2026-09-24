# Security evidence

Checked 2026-09-20; prefer the actual deployed artifact over this upstream snapshot.

- [Cfx security docs](https://docs.fivem.net/docs/developers/server-security/) and
  [event source lifetime](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/).
- CFX revision 0d8a2a6f78a9922445d8930305af82a7b1826980:
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua),
  RegisterNetEvent/SetEventRoutine/Citizen.Await;
  [ResourceScriptFunctions.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-core/src/ResourceScriptFunctions.cpp),
  GET_INVOKING_RESOURCE returns an invoking resource name/null, not authorization.
- [OneSync docs](https://docs.fivem.net/docs/scripting-reference/onesync/) and
  [ServerGameState_Scripting.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp):
  GET_ENTITY_COORDS reads the entity syncTree. Verify the relevant server native's declaration,
  entity/handle representation and routing behavior for the actual interaction.
- [State bag policy](https://docs.fivem.net/docs/scripting-manual/networking/state-bags/) and
  [StateBagPacketHandler.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-server-impl/src/packethandlers/StateBagPacketHandler.cpp):
  server strict-mode checks govern client writes; do not assume that deployment setting.
- In the Scripts Sky bridge workspace: inspect sky_base/SKY_BASE_DOCS_AI.md and
  sky_base/sky_base/source/server/modules/Security.lua, plus sky_jobs_base/SKY_JOBS_DOCS_AI.md
  for PlayerCache. Cooldown scope was inspected at sky_base
  d1ef6ad6df9a4eed355297b28fbdbe182cacf6ac; recheck current source when editing an action.

Source review does not prove deployed behavior or proprietary GTA internals. For an unresolved
native or concurrent/disconnect path, use a minimal runtime reproduction and report its limit.
