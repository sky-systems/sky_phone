Config.Command = "phone"

Config.Phone = {
    Item = "phone",
    DevelopmentCommand = false,
    DeviceName = "iFruit Phone",
    MaxDeviceDataBytes = 100000,
    AllowedDeviceNamespaces = {
        settings = true,
        notifications = true,
        wallpaper = true,
        alarms = true,
        media = true,
        apps = true,
    },
}

Config.Mail = {
    Domain = "ifruit.com",
    LocalPartMinLength = 3,
    LocalPartMaxLength = 32,
    PasswordMinLength = 6,
    PasswordMaxLength = 64,
    SubjectMaxLength = 120,
    BodyMaxLength = 20000,
    MaxRecipients = 10,
    PageSize = 50,
    AuthAttemptsPerMinute = 5,
}
