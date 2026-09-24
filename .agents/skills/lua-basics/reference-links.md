# Language and runtime sources

Checked 2026-09-20. Read the relevant section, not the entire manual.

- [Lua 5.4 manual](https://www.lua.org/manual/5.4/manual.html): values/truthiness (2.1),
  scope (3.5), errors (2.3), expressions/multiple returns (3.4), length (3.4.7),
  table.pack/unpack (6.6), const/close locals (3.3.7-3.3.8). Lua tables share references in ordinary calls.
- [LuaLS annotations](https://luals.github.io/wiki/annotations/): `@param`, optional types,
  `@return` and array types document the example API; annotations are not runtime checks.
- CFX docs: [Lua runtime](https://docs.fivem.net/docs/scripting-manual/runtimes/lua/),
  [event source lifetime](https://docs.fivem.net/docs/scripting-manual/working-with-events/listening-for-events/),
  [Await](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Await),
  [Wait](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/Citizen.Wait).
- CFX `0d8a2a6f78a9922445d8930305af82a7b1826980`:
  [scheduler.lua](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/data/shared/citizen/scripting/lua/scheduler.lua),
  Citizen.Await, SetEventRoutine, function references and export serialization;
  [LuaScriptRuntime.cpp](https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/citizen-scripting-lua/src/LuaScriptRuntime.cpp),
  Lua_Wait yields and Lua_CreateThreadInternal schedules.
- Its Lua submodule `4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a`:
  [ltable.c](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/ltable.c),
  luaH_getn/binsearch; [lua.h](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/lua.h)
  identifies LuaGLM 5.4.8. [llex.c](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/llex.c)
  and [lparser.c](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/lparser.c)
  support compound assignment such as `+=`; do not call it universally invalid in FiveM.
- Vectors: [CFX vector3/vec3 documentation](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/vector3/)
  lists both three-coordinate constructors. At the same Lua submodule revision,
  [lbaselib.c](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/lbaselib.c#L673-L677)
  registers `vec3` and `vector3` to the same `glmVec_vec3` global function;
  [lglm.cpp](https://github.com/citizenfx/lua/blob/4ee6aab505bca3346aa9dfafd8bc91bd14c85f1a/lglm.cpp#L1538-L1572)
  implements `glm_createVector`, called with dimension 3 by `glmVec_vec3` at line 1629.
  These are Cfx Lua values, not vanilla Lua constructors. Vector arguments passed into a native
  still need that native's binding/context verified, including the OAL exception in
  [manifest guidance](../fivem-basics/fxmanifest.md).

These are inspected upstream revisions, not the deployed artifact. For changed CFX/native use,
verify docs plus the relevant registration/generated binding and implementation at the matching
revision. Record client/server and yield constraints; proprietary engine behavior and actual
performance still require runtime evidence when material.
