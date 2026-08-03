const cors = require('cors')
const express = require('express')

const app = express()
const port = 3001

app.use(cors())
app.use(express.json())

app.post('/api/:endpoint', (request, response) => {
  console.log(`[NUI] ${request.params.endpoint}`, request.body)
  response.json({ success: true })
})

app.listen(port, () => {
  console.log(`Mock NUI server listening on http://localhost:${port}`)
})
