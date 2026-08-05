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
        definitions[#definitions + 1] = ("PRIMARY KEY (`%s`)"):format(table_definition.primaryKey)
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
    for index = 1, #schema do
        table_names[index] = schema[index].name
        placeholders[index] = "?"
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
