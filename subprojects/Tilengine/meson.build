project('Tilengine', 'c', version : '1.0', default_options : ['c_std=gnu99'])
sources = files(
    'src' / 'Animation.c',
    'src' / 'Base64.c',
    'src' / 'Bitmap.c',
    'src' / 'Blitters.c',
    'src' / 'Draw.c',
    'src' / 'Layer.c',
    'src' / 'List.c',
    'src' / 'LoadBitmap.c',
    'src' / 'LoadFile.c',
    'src' / 'LoadPalette.c',
    'src' / 'LoadSequencePack.c',
    'src' / 'LoadSpriteset.c',
    'src' / 'LoadTMX.c',
    'src' / 'LoadTilemap.c',
    'src' / 'LoadTileset.c',
    'src' / 'Math2D.c',
    'src' / 'Object.c',
    'src' / 'ObjectList.c',
    'src' / 'Palette.c',
    'src' / 'ResourcePacker.c',
    'src' / 'Sequence.c',
    'src' / 'SequencePack.c',
    'src' / 'Sprite.c',
    'src' / 'Spriteset.c',
    'src' / 'Tables.c',
    'src' / 'Tilemap.c',
    'src' / 'Tilengine.c',
    'src' / 'Tileset.c',
    'src' / 'World.c',
    'src' / 'aes.c',
    'src' / 'cJSON.c',
    'src' / 'crc32.c',
    'src' / 'md5.c',
    'src' / 'simplexml.c',
)

inc = include_directories('include')

link_args = []
deps = []
if host_machine.system() == 'windows'
  link_args += '-Wl,--export-all-symbols'
elif host_machine.system() == 'n3ds'
  m_dep = declare_dependency(link_args : ['-lm'])
  deps += m_dep
else
  cc = meson.get_compiler('c')
  m_dep = cc.find_library('m', required : true)
  deps += m_dep
endif

if host_machine.system() == 'windows'
  c_args = ['-O2', '-fpic', '-DLIB_EXPORTS']
else
  c_args = ['-O2', '-fpic', '-DLIB_EXPORTS', '-Wno-unused-result', '-Wno-format-truncation']
endif

if host_machine.system() != 'horizon' and host_machine.system() != 'emscripten' and host_machine.system() != 'n3ds' and not meson.get_external_property('spruce_no_openssl', false)
  c_args += '-DHAVE_OPENSSL'
  deps += dependency('openssl')
endif

lib = static_library('Tilengine', sources, dependencies : deps, include_directories : inc, link_args: link_args,  c_args : c_args)

#executable('Test', 'src/Test.c', include_directories : inc, link_with : lib)

tilengine_dep = declare_dependency(link_with : lib, include_directories : inc)
