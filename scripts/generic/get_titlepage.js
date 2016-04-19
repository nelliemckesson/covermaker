var fs = require('fs');
var cheerio = require('cheerio');
var file = process.argv[2];
var newfile = process.argv[3];

fs.readFile(file, function editContent (err, contents) {
  $ = cheerio.load(contents, {
          xmlMode: true
        });

  if ($('.TitlepageBookSubtitlestit + .TitlepageAuthorNameau').length > 1 ) {
    $('section[data-type="titlepage"]').addClass("anthology");
  };

  var content = $('section[data-type="titlepage"]');
  var $body = $( '<body></body>' );
  $body.append(content)
  var $head = $( '<head></head>' );
  $head.append( $('<title>Generated Titlepage</title>') );
  var output = $('html').empty().append( $head, $body );
    fs.writeFile(newfile, output, function(err) {
      if(err) {
          return console.log(err);
      }

      console.log("Content has been updated!");
  });
});