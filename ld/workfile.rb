#!/usr/bin/ruby

require File.expand_path('../common.rb')
require 'stringio'

srcdir = '.'
libdir = '.'
prefix = 'prefix'
exec_prefix = 'exec_prefix'
host = 'unknown'
target = CONFIG_TARGET
target_alias = target
EMULATION_LIBPATH = 'EMULATION_LIBPATH'
NATIVE_LIB_DIRS = 'NATIVE_LIB_DIRS'
use_sysroot = 'no'
enable_initfini_array = 'no'
GENSCRIPTS = "./genscripts.sh"+
	" \"#{srcdir}\" \"#{libdir}\" \"#{prefix}\" \"#{exec_prefix}\""+
	" #{host} #{target} #{target_alias}"+
	" \"#{EMULATION_LIBPATH}\" \"#{NATIVE_LIB_DIRS}\""+
	" #{use_sysroot} #{enable_initfini_array}"

class GenScriptsTask < MultiFileTask
	include FlagsChanged
	def initialize(work, target)
		@file = "eelf32#{target}.c"
		super(work, 'build/'+@file, [])
		@target = target
		@prerequisites += [
			'emultempl/elf32.em',
			'emultempl/elf-generic.em',
			'emultempl/generic.em',
			'genscripts.sh',
			"emulparams/elf32#{target}.sh",
		].collect do |p| FileTask.new(work, p) end
		initFlags
	end
	def cFlags
		return "bash -x #{GENSCRIPTS} elf32#{@target} \"build\""
	end
	def execute
		execFlags
		FileUtils.rm_f @NAME
		FileUtils.rm_f @file
		sh cFlags
		FileUtils.mv(@file, @NAME)
	end
end

class LdEmulListTask < MemoryGeneratedFileTask
	def initialize(work, targets)
		super(work, 'ldemul-list.h')

		io = StringIO.new
		first = true
		io.write("/* This file is automatically generated.  DO NOT EDIT! */\n")
		io.write("\n")
		targets.each do |t|
			io.write("extern ld_emulation_xfer_type ld_elf32#{t}_emulation;\n")
		end
		io.write("\n")
		io.write("#define EMULATION_LIST \\\n")
		targets.each do |t|
			io.write("\t&ld_elf32#{t}_emulation, \\\n")
		end
		io.write("\t0\n")
		@buf = io.string
	end
end


#eelf32openrisc.c: $(srcdir)/emulparams/elf32openrisc.sh \
#  $(ELF_DEPS) $(srcdir)/scripttempl/elf.sc ${GEN_DEPENDS}
#	${GENSCRIPTS} elf32openrisc "$(tdir_openrisc)"

work = BinutilsExeWork.new
work.instance_eval do
	@SOURCES = ['.']
	@EXTRA_SOURCEFILES = [
	]
	@EXTRA_SOURCETASKS = [
		YaccTask.new(self, 'deffilep.y'),
		YaccTask.new(self, 'ldgram.y'),
		GenScriptsTask.new(self, CONFIG_TARGET),
	]
	@PREREQUISITES = [
		FlexTask.new(self, 'ldlex.l'),
		LdEmulListTask.new(self, [CONFIG_TARGET])
	]
	@EXTRA_INCLUDES << '.'
	@EXTRA_INCLUDES << '../bfd'
	@IGNORED_FILES = [
		'plugin.c', # due to lack of dlopen()
		'ldlex.c',	# wrapped
		'pe-dll.c',	# don't need PE
		'pep-dll.c',	# don't need PE
		'deffilep.c',	# sourcetask
		'ldgram.c',	# sourcetask
	]
	@EXTRA_CFLAGS << ' -DHAVE_CONFIG_H=1 -DLOCALEDIR=0 -DUSING_CGEN=1'
	@EXTRA_CFLAGS << " -DTARGET=\\\"#{CONFIG_TARGET}-unknown-elf\\\""
	@EXTRA_CFLAGS << ' -DYYDEBUG=0'
	@EXTRA_CFLAGS << ' -DBINDIR=0 -DTOOLBINDIR=0'
	@EXTRA_CFLAGS << ' -DSCRIPTDIR=0'
	@EXTRA_CFLAGS << ' -DTESTING=0'
	@EXTRA_CFLAGS << ' -Wno-nested-externs'
	@SPECIFIC_CFLAGS = {
		'ldlex-wrapper.c' => ' -Wno-shadow',
		'ldmain.c' => " -DDEFAULT_EMULATION=\\\"elf32#{CONFIG_TARGET}\\\""
	}
	@LOCAL_LIBS = [
		'bfd',
		'libiberty',
	]
	@LIBRARIES = [
		'z',
	]
	if(HOST == :win32)
		@LIBRARIES << 'intl'
	else
		@LOCAL_LIBS << 'intl'
	end
	@NAME = 'ld'
end

work.invoke
