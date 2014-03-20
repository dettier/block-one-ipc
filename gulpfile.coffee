gulp   = require 'gulp'
gutil  = require 'gulp-util'
coffee = require 'gulp-coffee'
watch  = require 'gulp-watch'
mocha  = require 'gulp-mocha'

gulp.task 'test', () ->
    return gulp.src(['./test/**/*.js'], { read : false })
        .on 'data', (file) ->
            gulp.src(file.path)
                .pipe(mocha({ reporter : 'list' }))
                .on('error', gutil.log)

gulp.task 'watch-and-test', () ->
    gulp.src(['./lib/**/*.js'], { read: false })
        .pipe(watch((events, cb) ->
            gulp.run('test', cb)))
        .on('error', gutil.log)
    return

gulp.task 'compile', () ->
    gulp.src(['./src/**/*.coffee', './src/**/*.coffee'])
        .pipe(coffee({ bare : true, map : true }).on('error', gutil.log))
        .pipe(gulp.dest('./lib/'))

    gulp.src('./test/**/*.coffee')
        .pipe(coffee({ bare : true, map : true }).on('error', gutil.log))
        .pipe(gulp.dest('./test/'))

    return

gulp.task 'watch-and-compile', () ->
    gulp.src(['./src/**/*.coffee', './src/**/*.coffee'])
        .pipe(watch())
        .pipe(coffee({ bare : true, map : true }).on('error', gutil.log))
        .pipe(gulp.dest('./lib/'))

    gulp.src('./test/**/*.coffee')
        .pipe(watch())
        .pipe(coffee({ bare : true, map : true }).on('error', gutil.log))
        .pipe(gulp.dest('./test/'))

    return

gulp.task 'copy-files', () ->
    console.log 'COPY'
    gulp.src(['./src/**/*.json'])
        .pipe(watch())
        .pipe(gulp.dest('./lib'))

    
gulp.task 'default', () ->
    gulp.run('compile', 'watch-and-compile')
    gulp.run('watch-and-test')
    gulp.run('copy-files')