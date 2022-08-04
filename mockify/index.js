require('dotenv').config()

const express = require('express')
const cors = require('cors')

const app = express()
const port = Number.parseInt(process.env.PORT || 8079)
const path = process.env.DEFAULT_PATH
const amountOfResults = 5

const searchResults = []

console.log("[Mockify] Loading mock results")
for (let i = 1; i <= amountOfResults; i++) {
  let json = require('./search/' + i + '.json')
  searchResults.push(json)
}

app.use(cors())

app.get('/', (req, res) => res.send('Mockify'))
app.get(path, (req, res) => res.send('Mockify'))

app.get(path + 'search', (req, res) => {
  const time = (new Date()).getMinutes() % amountOfResults
  res.json(searchResults[time])
})

app.listen(port, () => {
  console.log(`[Mockify] Listening on port ${port} with default path http://localhost:${port}${path}`)
})
