data:extend({
  {
    type = "bool-setting",
    name = "hover-circuit-signals-enabled",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "a"
  },
  {
    type = "int-setting",
    name = "hover-circuit-signals-offset-x",
    setting_type = "runtime-per-user",
    default_value = 280,
    minimum_value = 0,
    maximum_value = 4096,
    order = "b"
  },
  {
    type = "int-setting",
    name = "hover-circuit-signals-offset-y",
    setting_type = "runtime-per-user",
    default_value = 220,
    minimum_value = 0,
    maximum_value = 4096,
    order = "c"
  },
  {
    type = "int-setting",
    name = "hover-circuit-signals-columns",
    setting_type = "runtime-per-user",
    default_value = 5,
    minimum_value = 1,
    maximum_value = 10,
    order = "d"
  },
  {
    type = "int-setting",
    name = "hover-circuit-signals-max-signals",
    setting_type = "runtime-per-user",
    default_value = 25,
    minimum_value = 1,
    maximum_value = 100,
    order = "e"
  },
  {
    type = "int-setting",
    name = "hover-circuit-signals-update-interval",
    setting_type = "runtime-per-user",
    default_value = 12,
    minimum_value = 1,
    maximum_value = 120,
    order = "f"
  },
  {
    type = "bool-setting",
    name = "hover-circuit-signals-show-network-id",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "h"
  },
  {
    type = "bool-setting",
    name = "hover-circuit-signals-compact-numbers",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "i"
  },
  {
    type = "bool-setting",
    name = "hover-circuit-signals-separate-io",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "j"
  },
  {
    type = "bool-setting",
    name = "hover-circuit-signals-separate-wire-color",
    setting_type = "runtime-per-user",
    default_value = true,
    order = "k"
  },
  {
    type = "string-setting",
    name = "hover-circuit-signals-sort-order",
    setting_type = "runtime-per-user",
    default_value = "prototype",
    allowed_values = { "prototype", "name", "count-desc" },
    order = "l"
  }
})
