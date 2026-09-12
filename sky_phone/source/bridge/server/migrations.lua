local completed_migrations = {}
local migration_callbacks = {}

local function build_column_definition(column)
    local data_type, attributes = column.type:match("^(%S+)%s*(.*)$")
    local definition = data_type

    if column.characterSet then
        definition = definition .. " CHARACTER SET " .. column.characterSet
    end
    if column.collation then
        definition = definition .. " COLLATE " .. column.collation
    end
    if attributes ~= "" then
        definition = definition .. " " .. attributes
    end

    return definition
end

local function build_create_query(table_definition)
    local definitions = {}
    for index = 1, #table_definition.columns do
        local column = table_definition.columns[index]
        definitions[#definitions + 1] = ("`%s` %s"):format(column.name, build_column_definition(column))
    end

    if table_definition.primaryKey then
        local primary_key = table_definition.primaryKey
        if type(primary_key) == "table" then
            local quoted_columns = {}
            for index = 1, #primary_key do
                quoted_columns[index] = ("`%s`"):format(primary_key[index])
            end
            definitions[#definitions + 1] = ("PRIMARY KEY (%s)"):format(table.concat(quoted_columns, ", "))
        else
            definitions[#definitions + 1] = ("PRIMARY KEY (`%s`)"):format(primary_key)
        end
    end
    for _, unique_key in ipairs(table_definition.uniqueKeys or {}) do
        definitions[#definitions + 1] = ("UNIQUE KEY `%s` %s"):format(unique_key.name, unique_key.columns)
    end
    for _, index in ipairs(table_definition.indexes or {}) do
        definitions[#definitions + 1] = ("INDEX `%s` %s"):format(index.name, index.columns)
    end
    for _, foreign_key in ipairs(table_definition.foreignKeys or {}) do
        definitions[#definitions + 1] = ("FOREIGN KEY (`%s`) REFERENCES %s"):format(
            foreign_key.column,
            foreign_key.references
        )
    end

    return ("CREATE TABLE IF NOT EXISTS `%s` (\n%s\n) %s"):format(
        table_definition.name,
        table.concat(definitions, ",\n"),
        table_definition.tableOptions or ""
    )
end

local function query_or_error(query, parameters, context)
    local success, result = pcall(Bridge.Database.Query, query, parameters)
    if not success then
        error(("[sky_phone] Database migration failed while %s: %s"):format(context, tostring(result)))
    end
    return result
end

local function column_key(table_name, column_name)
    return ("%s\0%s"):format(table_name:lower(), column_name:lower())
end

local function quote_identifier(identifier)
    return ("`%s`"):format(tostring(identifier):gsub("`", "``"))
end

local function read_foreign_keys(table_names, include_incoming)
    if not table_names[1] then
        return {}
    end

    local placeholders = {}
    local parameters = {}
    for index, table_name in ipairs(table_names) do
        placeholders[index] = "?"
        parameters[index] = table_name
    end
    local table_filter = ("TABLE_NAME IN (%s)"):format(table.concat(placeholders, ", "))
    if include_incoming then
        table_filter = table_filter .. (" OR REFERENCED_TABLE_NAME IN (%s)"):format(table.concat(placeholders, ", "))
        for _, table_name in ipairs(table_names) do
            parameters[#parameters + 1] = table_name
        end
    end

    -- Read constraint headers first, then columns only for their owning tables.
    local rows = query_or_error(([[
        SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME, UPDATE_RULE, DELETE_RULE
        FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
            AND UNIQUE_CONSTRAINT_SCHEMA = DATABASE()
            AND (%s)
        ORDER BY TABLE_NAME, CONSTRAINT_NAME
    ]]):format(table_filter), parameters, "reading foreign key constraints")
    local foreign_keys = {}
    local foreign_keys_by_name = {}
    local owner_tables = {}
    local owner_table_names = {}
    local owner_placeholders = {}

    for _, row in ipairs(rows) do
        local table_name = row.table_name or row.TABLE_NAME
        local constraint_name = row.constraint_name or row.CONSTRAINT_NAME
        local key = ("%s\0%s"):format(table_name:lower(), constraint_name:lower())
        local foreign_key = {
            name = constraint_name,
            table_name = table_name,
            referenced_table_name = row.referenced_table_name or row.REFERENCED_TABLE_NAME,
            update_rule = row.update_rule or row.UPDATE_RULE,
            delete_rule = row.delete_rule or row.DELETE_RULE,
            columns = {},
            referenced_columns = {},
        }
        foreign_keys_by_name[key] = foreign_key
        foreign_keys[#foreign_keys + 1] = foreign_key
        if not owner_tables[table_name] then
            owner_tables[table_name] = true
            owner_table_names[#owner_table_names + 1] = table_name
            owner_placeholders[#owner_placeholders + 1] = "?"
        end
    end

    if not foreign_keys[1] then
        return foreign_keys
    end

    local columns = query_or_error(([[
        SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_COLUMN_NAME
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE()
            AND TABLE_NAME IN (%s)
            AND REFERENCED_TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME, CONSTRAINT_NAME, ORDINAL_POSITION
    ]]):format(table.concat(owner_placeholders, ", ")), owner_table_names, "reading foreign key columns")
    for _, row in ipairs(columns) do
        local table_name = row.table_name or row.TABLE_NAME
        local constraint_name = row.constraint_name or row.CONSTRAINT_NAME
        local key = ("%s\0%s"):format(table_name:lower(), constraint_name:lower())
        local foreign_key = foreign_keys_by_name[key]
        if foreign_key then
            foreign_key.columns[#foreign_key.columns + 1] = row.column_name or row.COLUMN_NAME
            foreign_key.referenced_columns[#foreign_key.referenced_columns + 1] =
                row.referenced_column_name or row.REFERENCED_COLUMN_NAME
        end
    end

    return foreign_keys
end

local valid_foreign_key_rules = {
    CASCADE = true,
    ["NO ACTION"] = true,
    RESTRICT = true,
    ["SET DEFAULT"] = true,
    ["SET NULL"] = true,
}

local function build_foreign_key_definition(foreign_key)
    local columns = {}
    local referenced_columns = {}
    for index = 1, #foreign_key.columns do
        columns[index] = quote_identifier(foreign_key.columns[index])
        referenced_columns[index] = quote_identifier(foreign_key.referenced_columns[index])
    end

    local update_rule = tostring(foreign_key.update_rule):upper()
    local delete_rule = tostring(foreign_key.delete_rule):upper()
    if not valid_foreign_key_rules[update_rule] or not valid_foreign_key_rules[delete_rule] then
        error(("[sky_phone] Cannot preserve foreign key '%s': unsupported referential action."):format(
            tostring(foreign_key.name)
        ))
    end

    return ("CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s) ON DELETE %s ON UPDATE %s"):format(
        quote_identifier(foreign_key.name),
        table.concat(columns, ", "),
        quote_identifier(foreign_key.referenced_table_name),
        table.concat(referenced_columns, ", "),
        delete_rule,
        update_rule
    )
end

local function foreign_key_touches_columns(foreign_key, changed_columns)
    for index = 1, #foreign_key.columns do
        if changed_columns[column_key(foreign_key.table_name, foreign_key.columns[index])]
            or changed_columns[column_key(foreign_key.referenced_table_name, foreign_key.referenced_columns[index])] then
            return true
        end
    end
    return false
end

local function desired_foreign_key_target(references)
    local table_name, column_list = references:match("^%s*`([^`]+)`%s*%(([^%)]+)%)")
    local column_name = column_list and column_list:match("^%s*`([^`]+)`%s*$")
    if not table_name or not column_name then
        error(("[sky_phone] Unsupported foreign key reference definition: %s"):format(tostring(references)))
    end
    return table_name, column_name
end

function Bridge.Database.EnsureIndex(table_name, index_name, columns, options)
    local table_count = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
    ]], { table_name })
    if not table_count[1] or tonumber(table_count[1].count) == 0 then
        return false
    end

    local indexes = Bridge.Database.Query(("SHOW INDEX FROM `%s`"):format(table_name), {})
    for _, index in ipairs(indexes) do
        if index.Key_name == index_name then
            return false
        end
    end

    local index_type = options and options.unique and "UNIQUE KEY" or "INDEX"
    query_or_error(
        ("ALTER TABLE `%s` ADD %s `%s` %s"):format(table_name, index_type, index_name, columns),
        {},
        ("adding index '%s'"):format(index_name)
    )
    Bridge.Debug("info", "[sky_phone] Added database index '%s' to '%s'.", index_name, table_name)
    return true
end

function Bridge.Database.Migrate(migration_name, schema)
    local table_names = {}
    local placeholders = {}
    local schema_tables = {}
    for index = 1, #schema do
        table_names[index] = schema[index].name
        placeholders[index] = "?"
        schema_tables[schema[index].name:lower()] = true
    end

    local existing_tables = {}
    local existing_columns = {}
    if #table_names > 0 then
        local placeholder_list = table.concat(placeholders, ", ")
        local tables = Bridge.Database.Query(([[
            SELECT TABLE_NAME
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (%s)
        ]]):format(placeholder_list), table_names)
        for _, row in ipairs(tables) do
            existing_tables[(row.TABLE_NAME or row.table_name):lower()] = true
        end

        local columns = Bridge.Database.Query(([[
            SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (%s)
        ]]):format(placeholder_list), table_names)
        for _, row in ipairs(columns) do
            local table_name = (row.TABLE_NAME or row.table_name):lower()
            local column_name = (row.COLUMN_NAME or row.column_name):lower()
            existing_columns[table_name] = existing_columns[table_name] or {}
            existing_columns[table_name][column_name] = {
                character_set = row.CHARACTER_SET_NAME or row.character_set_name,
                collation = row.COLLATION_NAME or row.collation_name,
            }
        end
    end

    local changed_columns = {}
    local changed_table_names = {}
    for _, table_definition in ipairs(schema) do
        local table_name = table_definition.name:lower()
        if existing_tables[table_name] then
            local columns = existing_columns[table_name] or {}
            local table_changed = false
            for _, column in ipairs(table_definition.columns) do
                local current = columns[column.name:lower()]
                if current and ((column.characterSet and current.character_set ~= column.characterSet)
                    or (column.collation and current.collation ~= column.collation)) then
                    changed_columns[column_key(table_definition.name, column.name)] = true
                    table_changed = true
                end
            end
            if table_changed then
                changed_table_names[#changed_table_names + 1] = table_definition.name
            end
        end
    end

    local preserved_foreign_keys = {}
    if next(changed_columns) then
        for _, foreign_key in ipairs(read_foreign_keys(changed_table_names, true)) do
            if foreign_key_touches_columns(foreign_key, changed_columns) then
                if not schema_tables[foreign_key.table_name:lower()]
                    or not schema_tables[foreign_key.referenced_table_name:lower()] then
                    error((
                        "[sky_phone] Cannot safely update constrained columns because foreign key '%s.%s' is not fully owned by this migration."
                    ):format(foreign_key.table_name, foreign_key.name))
                end
                preserved_foreign_keys[#preserved_foreign_keys + 1] = foreign_key
            end
        end

        for _, foreign_key in ipairs(preserved_foreign_keys) do
            query_or_error(
                ("ALTER TABLE %s DROP FOREIGN KEY %s"):format(
                    quote_identifier(foreign_key.table_name),
                    quote_identifier(foreign_key.name)
                ),
                {},
                ("temporarily removing foreign key '%s.%s'"):format(foreign_key.table_name, foreign_key.name)
            )
        end
    end

    for _, table_definition in ipairs(schema) do
        local table_name = table_definition.name:lower()
        if not existing_tables[table_name] then
            query_or_error(build_create_query(table_definition), {}, ("creating table '%s'"):format(table_definition.name))
            Bridge.Debug("info", "[sky_phone] Created database table '%s'.", table_definition.name)
        else
            local columns = existing_columns[table_name] or {}
            for _, column in ipairs(table_definition.columns) do
                local current = columns[column.name:lower()]
                local definition = build_column_definition(column)
                if not current then
                    query_or_error(
                        ("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(table_definition.name, column.name, definition),
                        {},
                        ("adding column '%s.%s'"):format(table_definition.name, column.name)
                    )
                elseif (column.characterSet and current.character_set ~= column.characterSet)
                    or (column.collation and current.collation ~= column.collation) then
                    query_or_error(
                        ("ALTER TABLE `%s` MODIFY COLUMN `%s` %s"):format(table_definition.name, column.name, definition),
                        {},
                        ("updating column '%s.%s'"):format(table_definition.name, column.name)
                    )
                end
            end

            for _, index in ipairs(table_definition.indexes or {}) do
                Bridge.Database.EnsureIndex(table_definition.name, index.name, index.columns)
            end
        end
    end

    for _, foreign_key in ipairs(preserved_foreign_keys) do
        query_or_error(
            ("ALTER TABLE %s ADD %s"):format(
                quote_identifier(foreign_key.table_name),
                build_foreign_key_definition(foreign_key)
            ),
            {},
            ("restoring foreign key '%s.%s'"):format(foreign_key.table_name, foreign_key.name)
        )
    end

    local existing_foreign_key_columns = {}
    local existing_foreign_key_targets = {}
    for _, foreign_key in ipairs(read_foreign_keys(table_names)) do
        for index = 1, #foreign_key.columns do
            local key = column_key(foreign_key.table_name, foreign_key.columns[index])
            existing_foreign_key_columns[key] = true
            existing_foreign_key_targets[("%s\0%s\0%s"):format(
                key,
                foreign_key.referenced_table_name:lower(),
                foreign_key.referenced_columns[index]:lower()
            )] = true
        end
    end

    for _, table_definition in ipairs(schema) do
        for _, foreign_key in ipairs(table_definition.foreignKeys or {}) do
            local referenced_table_name, referenced_column_name = desired_foreign_key_target(foreign_key.references)
            local key = column_key(table_definition.name, foreign_key.column)
            local target_key = ("%s\0%s\0%s"):format(
                key,
                referenced_table_name:lower(),
                referenced_column_name:lower()
            )
            if not existing_foreign_key_targets[target_key] then
                if existing_foreign_key_columns[key] then
                    error((
                        "[sky_phone] Column '%s.%s' has a foreign key that does not match the migration schema."
                    ):format(table_definition.name, foreign_key.column))
                end

                query_or_error(
                    ("ALTER TABLE %s ADD FOREIGN KEY (%s) REFERENCES %s"):format(
                        quote_identifier(table_definition.name),
                        quote_identifier(foreign_key.column),
                        foreign_key.references
                    ),
                    {},
                    ("restoring missing foreign key for '%s.%s'"):format(table_definition.name, foreign_key.column)
                )
                existing_foreign_key_columns[key] = true
                existing_foreign_key_targets[target_key] = true
            end
        end
    end

end

function Bridge.Database.CompleteMigration(migration_name)
    if completed_migrations[migration_name] then
        error(("[sky_phone] Database migration '%s' was completed more than once."):format(tostring(migration_name)))
    end

    completed_migrations[migration_name] = true
    local callbacks = migration_callbacks[migration_name] or {}
    migration_callbacks[migration_name] = nil

    Bridge.Debug("info", "[sky_phone] Database migration '%s' completed.", migration_name)
    for index = 1, #callbacks do
        callbacks[index]()
    end
end

function Bridge.Database.AfterMigration(migration_name, callback)
    if type(callback) ~= "function" then
        error("[sky_phone] Database migration callback must be a function.")
    end
    if completed_migrations[migration_name] then
        callback()
        return
    end

    migration_callbacks[migration_name] = migration_callbacks[migration_name] or {}
    migration_callbacks[migration_name][#migration_callbacks[migration_name] + 1] = callback
end

function Bridge.Database.AwaitMigration(migration_name)
    if completed_migrations[migration_name] then
        return true
    end

    Bridge.Debug("error", "[sky_phone] Database migration '%s' has not completed.", tostring(migration_name))
    return false
end
