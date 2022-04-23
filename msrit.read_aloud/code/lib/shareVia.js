module.exports = function shareVia (data) {
  let uri = "http://bixby-read-aloud.com/?data="

  let encodedUri  = uri+ encodeURIComponent(JSON.stringify(data))

  return {
    uri:encodedUri,
    json:JSON.stringify(data),
    message:data.message
  }
  
}

