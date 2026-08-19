local picchat_table = "lbpicchat_logged_in"
local picchat_phone_column = "phone_number"
local sky_phone_table = "sky_phone_sims"
local sky_phone_column = "phone_number"
local sky_phone_constraint = "fk_lbpicchat_logged_in_sky_phone"

local function quote_identifier(identifier)
    if type(identifier) ~= "string" or not identifier:match("^[%w_]+$") then
        error(("[sky_phone] Rejected invalid database identifier '%s'."):format(tostring(identifier)))
    end

    return ("`%s`"):format(identifier)
end

local function migrate_picchat_phone_reference()
    local columns = Bridge.Database.Query([[
        SELECT `COLUMN_NAME`
        FROM `INFORMATION_SCHEMA`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = ? AND `COLUMN_NAME` = ?
        LIMIT 1
    ]], { picchat_table, picchat_phone_column })
    if not columns[1] then
        return
    end

    local references = Bridge.Database.Query([[
        SELECT keys.`CONSTRAINT_NAME`, keys.`REFERENCED_TABLE_NAME`, keys.`REFERENCED_COLUMN_NAME`
        FROM `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE` keys
        WHERE keys.`TABLE_SCHEMA` = DATABASE()
            AND keys.`TABLE_NAME` = ?
            AND keys.`COLUMN_NAME` = ?
            AND keys.`REFERENCED_TABLE_NAME` IS NOT NULL
    ]], { picchat_table, picchat_phone_column })

    local has_sky_phone_reference = false
    for _, reference in ipairs(references) do
        local referenced_table = tostring(reference.REFERENCED_TABLE_NAME or reference.referenced_table_name):lower()
        local referenced_column = tostring(reference.REFERENCED_COLUMN_NAME or reference.referenced_column_name):lower()
        local constraint_name = reference.CONSTRAINT_NAME or reference.constraint_name
        if referenced_table == sky_phone_table and referenced_column == sky_phone_column then
            has_sky_phone_reference = true
        elseif referenced_table == "phone_phones" and referenced_column == picchat_phone_column then
            Bridge.Database.Query(("ALTER TABLE %s DROP FOREIGN KEY %s"):format(
                quote_identifier(picchat_table),
                quote_identifier(constraint_name)
            ), {})
            Bridge.Debug(
                "info",
                "[sky_phone] Removed legacy PicChat phone reference '%s'.",
                tostring(constraint_name),
                { notice = true }
            )
        else
            Bridge.Debug(
                "error",
                "[sky_phone] PicChat phone identity uses unsupported reference %s.%s; automatic migration stopped.",
                referenced_table,
                referenced_column
            )
            return
        end
    end

    if has_sky_phone_reference then
        return
    end

    Bridge.Database.Query(([[
        ALTER TABLE %s
        MODIFY COLUMN %s VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
    ]]):format(
        quote_identifier(picchat_table),
        quote_identifier(picchat_phone_column)
    ), {})

    local orphan_rows = Bridge.Database.Query(([[
        SELECT COUNT(*) AS `count`
        FROM %s picchat
        LEFT JOIN %s sim ON sim.%s = picchat.%s
        WHERE picchat.%s IS NOT NULL AND sim.%s IS NULL
    ]]):format(
        quote_identifier(picchat_table),
        quote_identifier(sky_phone_table),
        quote_identifier(sky_phone_column),
        quote_identifier(picchat_phone_column),
        quote_identifier(picchat_phone_column),
        quote_identifier(sky_phone_column)
    ), {})
    local orphan_count = orphan_rows[1] and tonumber(orphan_rows[1].count) or 0
    if orphan_count > 0 then
        Bridge.Debug(
            "warn",
            "[sky_phone] PicChat contains %s account(s) without a Sky SIM. Legacy data was preserved; run 'skyphone:migrate lb-phone' and restart sky_phone to restore the foreign key.",
            tostring(orphan_count)
        )
        return
    end

    Bridge.Database.Query(([[
        ALTER TABLE %s
        ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s)
        ON DELETE CASCADE ON UPDATE CASCADE
    ]]):format(
        quote_identifier(picchat_table),
        quote_identifier(sky_phone_constraint),
        quote_identifier(picchat_phone_column),
        quote_identifier(sky_phone_table),
        quote_identifier(sky_phone_column)
    ), {})
    Bridge.Debug(
        "info",
        "[sky_phone] PicChat phone identities now reference sky_phone_sims.",
        { notice = true }
    )
end

Bridge.Database.AfterMigration("sky_phone", migrate_picchat_phone_reference)
