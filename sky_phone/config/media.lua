Config.Media = {
    GiphyApiKey = "",
    GifPageSize = 24,
    GifRating = "pg-13",
    UrlMaxLength = 2048,
    AllowedGifHosts = { "giphy.com" },
    FiveManage = {
        ApiKey = "e4UZ9y39JfkxHoZMAgRUVK6KMQsNCKPJ", -- Dashboard -> Tokens -> create a token with Media access.
        BaseUrl = "https://api.fivemanage.com/api/v3/file",
        RequestTimeoutMs = 10000,
        UploadTimeoutMs = 25000,
    },
    Photo = {
        Encoding = "jpg",
        Quality = 0.95,
    },
    Video = {
        BitrateKbps = 1500,
    },
    UploadSessionTimeoutMs = 60000,
    PageSize = 30,
}
