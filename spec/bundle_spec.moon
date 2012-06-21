import bundle from vilu
import File from vilu.fs

describe 'bundle', ->

  with_bundle_dir = (name, f) ->
    with_tmpdir (dir) ->
      b_dir = dir / name
      b_dir\mkdir!
      f b_dir

  describe 'load(dir)', ->
    it 'raises an error if dir is not a directory', ->
      assert_raises 'directory', -> bundle.load File '/not-a-directory'

    it 'raises an error if the bundle init file is missing or incomplete', ->
      with_tmpdir (dir) ->
        assert_raises 'bundle init', -> bundle.load dir
        init = dir / 'init.lua'
        init\touch!
        assert_raises 'Incorrect bundle', -> bundle.load dir
        init.contents = 'return {}'
        assert_raises 'info missing', -> bundle.load dir
        init.contents = 'return { info = {} }'
        assert_raises 'missing field', -> bundle.load dir

    it 'assigns the returned bundle table to bundles using the dir basename', ->
      mod = name: 'bundle_test', author: 'bundle_spec', description: 'spec_bundle', license: 'MIT'
      ret = 'return { info = {'
      ret ..= table.concat [k .. '="' .. v .. '"' for k,v in pairs mod], ','
      ret ..= '} }'
      with_bundle_dir 'foo', (dir) ->
        dir\join('init.lua').contents = ret
        bundle.load dir
        assert_table_equal bundles.foo, info: mod

    it 'massages the assigned module name to fit with naming standards if necessary', ->
      with_bundle_dir 'Test-hello 2', (dir) ->
        dir\join('init.lua').contents = [[
          return {
            info = {
              name = 'test',
              author = 'spec',
              description = 'desc',
              license = 'MIT',
            },
          }
        ]]
        bundle.load dir
        assert_not_nil bundles.test_hello_2

    it 'exposes a bundle_file function for accessing bundle files', ->
      with_bundle_dir 'test', (dir) ->
        dir\join('init.lua').contents = [[
          local file = bundle_file('bundle_aux.lua')
          return {
            info = {
              name = 'test',
              author = 'spec',
              description = 'desc',
              license = 'MIT',
            },
            file = file
          }
        ]]
        bundle.load dir
        assert_equal bundles.test.file, dir / 'bundle_aux.lua'

    describe 'bundle_load', ->
      it 'allows for cached loading of bundle files using relative paths', ->
        with_bundle_dir 'load', (dir) ->
          dir\join('aux.lua').contents = [[
            _G.load_count = _G.load_count or 0
            _G.load_count = _G.load_count + 1
            return 'foo' .. _G.load_count
          ]]
          dir\join('aux2.moon').contents = 'return bundle_load("aux.lua")'
          dir\join('init.lua').contents = [[
            bundle_load('aux.lua')
            return {
              info = {
                name = 'test',
                author = 'spec',
                description = 'desc',
                license = 'MIT',
              },
              aux = bundle_load('aux.lua'),
              aux2 = bundle_load('aux2.moon')
            }
          ]]
          bundle.load dir
          assert_equal bundles.load.aux, 'foo1'
          assert_equal bundles.load.aux2, 'foo1'

      it 'signals an error upon cyclic dependencies', ->
        with_bundle_dir 'cyclic', (dir) ->
          dir\join('aux.lua').contents = 'bundle_load("aux2.lua")'
          dir\join('aux2.lua').contents = 'bundle_load("aux.lua")'
          dir\join('init.lua').contents = [[
            bundle_load('aux.lua')
            return {
              info = {
                name = 'test',
                author = 'spec',
                description = 'desc',
                license = 'MIT',
              },
            }
          ]]
          assert_raises 'Cyclic dependency', -> bundle.load dir

      it 'allows passing parameters to the loaded file', ->
        with_bundle_dir 'load', (dir) ->
          dir\join('aux.lua').contents = 'return ...'
          dir\join('init.lua').contents = [[
            return {
              info = {
                name = 'test',
                author = 'spec',
                description = 'desc',
                license = 'MIT',
              },
              aux = bundle_load('aux.lua', 123),
            }
          ]]
          bundle.load dir
          assert_equal bundles.load.aux, 123

    it 'raises an error upon implicit global writes', ->
      with_tmpdir (dir) ->
        dir\join('init.lua').contents = [[
          file = bundle_file('bundle_aux.lua')
          return {
            info = {
              name = 'test',
              author = 'spec',
              description = 'desc',
              license = 'MIT',
            },
            file = file
          }
        ]]
        assert_raises 'implicit global', -> bundle.load dir
