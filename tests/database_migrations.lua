local migration_path = "sky_phone/source/bridge/server/migrations.lua"

local function assert_contains(value, expected, label)
    assert(value:find(expected, 1, true), ("%s did not contain '%s': %s"):format(label, expected, value))
end

local function find_operation(operations, expected)
    for index, operation in ipairs(operations) do
        if operation:find(expected, 1, true) then
            return index
        end
    end
    return nil
end

local function run_migration(options)
    local operations = {}
    local metadata_queries = {}
    Bridge = {
        Database = {},
        Debug = function() end,
    }

    local foreign_key_rows = options.foreign_keys or {
        {
            constraint_name = "phone_children_ibfk_1",
            table_name = "phone_children",
            column_name = "parent_id",
            referenced_table_name = "phone_parents",
            referenced_column_name = "id",
            update_rule = "RESTRICT",
            delete_rule = "CASCADE",
        },
    }
    if options.missing_foreign_key then
        foreign_key_rows = {}
    end

    function Bridge.Database.Query(query, parameters)
        if query:find("FROM INFORMATION_SCHEMA.TABLES", 1, true) then
            return {
                { TABLE_NAME = "phone_parents" },
                { TABLE_NAME = "phone_children" },
            }
        end
        if query:find("FROM INFORMATION_SCHEMA.COLUMNS", 1, true) then
            return {
                {
                    TABLE_NAME = "phone_parents",
                    COLUMN_NAME = "id",
                    CHARACTER_SET_NAME = options.parent_character_set or "utf8mb4",
                    COLLATION_NAME = options.parent_collation or "utf8mb4_unicode_ci",
                },
                {
                    TABLE_NAME = "phone_children",
                    COLUMN_NAME = "parent_id",
                    CHARACTER_SET_NAME = options.child_character_set or "utf8mb4",
                    COLLATION_NAME = options.child_collation or "utf8mb4_unicode_ci",
                },
            }
        end
        if query:find("FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS", 1, true)
            or query:find("FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE", 1, true) then
            metadata_queries[#metadata_queries + 1] = { query = query, parameters = parameters }
            local is_header = query:find("FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS", 1, true)
            local include_incoming = query:find("OR REFERENCED_TABLE_NAME IN", 1, true)
            local selected_tables = {}
            for _, table_name in ipairs(parameters) do
                selected_tables[table_name] = true
            end
            local rows = {}
            local seen = {}
            for _, row in ipairs(foreign_key_rows) do
                local key = row.table_name .. "\0" .. row.constraint_name
                if (selected_tables[row.table_name] or (include_incoming and selected_tables[row.referenced_table_name]))
                    and (not is_header or not seen[key]) then
                    rows[#rows + 1] = row
                    seen[key] = true
                end
            end
            return rows
        end
        if query:find("SHOW INDEX FROM", 1, true) then
            return {}
        end

        operations[#operations + 1] = query
        return {}
    end

    assert(loadfile(migration_path))()
    local schema = {
        {
            name = "phone_parents",
            columns = {
                { name = "id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            },
            primaryKey = "id",
        },
        {
            name = "phone_children",
            columns = {
                { name = "parent_id", type = "CHAR(36) NOT NULL", characterSet = "ascii", collation = "ascii_bin" },
            },
            foreignKeys = {
                { column = "parent_id", references = "`phone_parents` (`id`) ON DELETE CASCADE" },
            },
        },
    }
    if options.no_foreign_keys then
        schema[2].foreignKeys = nil
    end
    local success, reason = pcall(Bridge.Database.Migrate, "test", schema)
    if options.expected_error then
        assert(not success, "unsafe migration unexpectedly succeeded")
        assert_contains(reason, options.expected_error, "migration failure")
    else
        assert(success, reason)
    end

    return operations, metadata_queries
end

local operations = run_migration({})
local drop_index = assert(find_operation(operations, "DROP FOREIGN KEY `phone_children_ibfk_1`"))
local parent_modify_index = assert(find_operation(operations, "MODIFY COLUMN `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL"))
local child_modify_index = assert(find_operation(operations, "MODIFY COLUMN `parent_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL"))
local restore_index = assert(find_operation(operations, "ADD CONSTRAINT `phone_children_ibfk_1`"))
assert(drop_index < parent_modify_index, "foreign key must be dropped before the parent column changes")
assert(drop_index < child_modify_index, "foreign key must be dropped before the child column changes")
assert(restore_index > parent_modify_index, "foreign key must be restored after the parent column changes")
assert(restore_index > child_modify_index, "foreign key must be restored after the child column changes")
assert_contains(operations[restore_index], "ON DELETE CASCADE ON UPDATE RESTRICT", "restored foreign key")

operations = run_migration({
    missing_foreign_key = true,
})
assert(not find_operation(operations, "DROP FOREIGN KEY"), "an already missing foreign key must not be dropped again")
parent_modify_index = assert(find_operation(operations, "MODIFY COLUMN `id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL"))
child_modify_index = assert(find_operation(operations, "MODIFY COLUMN `parent_id` CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL"))
local missing_restore_index = assert(find_operation(
    operations,
    "ALTER TABLE `phone_children` ADD FOREIGN KEY (`parent_id`) REFERENCES `phone_parents` (`id`) ON DELETE CASCADE"
))
assert(missing_restore_index > parent_modify_index, "missing foreign key must be restored after the parent column changes")
assert(missing_restore_index > child_modify_index, "missing foreign key must be restored after the child column changes")

print("database migration foreign key checks passed")

local metadata_queries
operations, metadata_queries = run_migration({
    parent_character_set = "ascii", parent_collation = "ascii_bin",
    child_character_set = "ascii", child_collation = "ascii_bin",
})
assert(#operations == 0, "an unchanged schema must not issue DDL")
assert(#metadata_queries == 2, "an unchanged schema needs one scoped header/column read")
for _, metadata in ipairs(metadata_queries) do
    assert(not metadata.query:find("JOIN", 1, true), "metadata tables must not be joined")
    assert(not metadata.query:find("OR REFERENCED_TABLE_NAME IN", 1, true), "incoming scan is only needed for changes")
    assert(#metadata.parameters > 0, "foreign key metadata must be scoped to explicit tables")
end
assert(#metadata_queries[2].parameters == 1 and metadata_queries[2].parameters[1] == "phone_children",
    "key columns must only be read for the discovered constraint owners")

operations, metadata_queries = run_migration({
    parent_character_set = "ascii", parent_collation = "ascii_bin",
    child_character_set = "ascii", child_collation = "ascii_bin",
    missing_foreign_key = true, no_foreign_keys = true,
})
assert(#operations == 0 and #metadata_queries == 1, "no constraints means no key-column query")

operations = run_migration({
    foreign_keys = {
        {
            constraint_name = "external_parent", table_name = "external_children", column_name = "parent_id",
            referenced_table_name = "phone_parents", referenced_column_name = "id",
            update_rule = "RESTRICT", delete_rule = "CASCADE",
        },
    },
    expected_error = "not fully owned by this migration",
})
assert(#operations == 0, "external incoming constraints must stop migration before DDL")

operations = run_migration({
    foreign_keys = {
        {
            constraint_name = "external_target", table_name = "phone_children", column_name = "parent_id",
            referenced_table_name = "external_parents", referenced_column_name = "id",
            update_rule = "RESTRICT", delete_rule = "CASCADE",
        },
    },
    expected_error = "not fully owned by this migration",
})
assert(#operations == 0, "external outgoing constraints must stop migration before DDL")

operations = run_migration({
    foreign_keys = {
        {
            constraint_name = "composite_parent", table_name = "phone_children", column_name = "parent_id",
            referenced_table_name = "phone_parents", referenced_column_name = "id",
            update_rule = "CASCADE", delete_rule = "RESTRICT",
        },
        {
            constraint_name = "composite_parent", table_name = "phone_children", column_name = "tenant_id",
            referenced_table_name = "phone_parents", referenced_column_name = "tenant_id",
            update_rule = "CASCADE", delete_rule = "RESTRICT",
        },
        {
            constraint_name = "composite_parent", table_name = "phone_parents", column_name = "tenant_id",
            referenced_table_name = "phone_children", referenced_column_name = "tenant_id",
            update_rule = "RESTRICT", delete_rule = "CASCADE",
        },
    },
})
restore_index = assert(find_operation(operations, "ADD CONSTRAINT `composite_parent`"))
assert_contains(operations[restore_index], "FOREIGN KEY (`parent_id`, `tenant_id`) REFERENCES `phone_parents` (`id`, `tenant_id`)",
    "composite foreign key column order")
assert_contains(operations[restore_index], "ON DELETE RESTRICT ON UPDATE CASCADE", "composite referential actions")
assert(not find_operation(operations, "ALTER TABLE `phone_parents` DROP FOREIGN KEY"),
    "same-named constraints on different tables must stay separate")

operations = run_migration({
    parent_character_set = "ascii", parent_collation = "ascii_bin",
    child_character_set = "ascii", child_collation = "ascii_bin",
    foreign_keys = {
        {
            constraint_name = "wrong_target", table_name = "phone_children", column_name = "parent_id",
            referenced_table_name = "other_parents", referenced_column_name = "id",
            update_rule = "RESTRICT", delete_rule = "CASCADE",
        },
    },
    expected_error = "does not match the migration schema",
})
assert(#operations == 0, "conflicting constraints must not be overwritten")

Bridge.Database.Query = function()
    error("an empty schema must not read database metadata")
end
Bridge.Database.Migrate("empty", {})
print("database migration scoped metadata checks passed")
