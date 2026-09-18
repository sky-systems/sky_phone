SkyPhoneConfiguratorSchema = {
    name = "sky_phone_configurator",
    columns = {
        { name = "id", type = "TINYINT UNSIGNED NOT NULL" },
        { name = "config_payload", type = "LONGTEXT NOT NULL" },
        { name = "media_payload", type = "LONGTEXT NOT NULL" },
        { name = "revision", type = "INT UNSIGNED NOT NULL DEFAULT 1" },
        {
            name = "updated_by_identifier",
            type = "VARCHAR(80) NULL",
            characterSet = "ascii",
            collation = "ascii_bin",
        },
        { name = "updated_by_name", type = "VARCHAR(120) NULL" },
        { name = "created_at", type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" },
        {
            name = "updated_at",
            type = "DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP",
        },
    },
    primaryKey = "id",
    tableOptions = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
}
