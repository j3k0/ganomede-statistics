#
# Run a single step of statistics computation
#

stats = require('./src/statistics').createApi()
stats.runFetcherStep ->
  stats.quit()
