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
    Bridge = {
        Database = {},
        Debug = function() end,
    }

    function Bridge.Database.Query(query)
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
        if query:find("FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu", 1, true) then
            if options.missing_foreign_key then
                return {}
            end
            return {
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
        end
        if query:find("SHOW INDEX FROM", 1, true) then
            return {}
        end

        operations[#operations + 1] = query
        return {}
    end

    assert(loadfile(migration_path))()
    Bridge.Database.Migrate("test", {
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
    })

    return operations
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
