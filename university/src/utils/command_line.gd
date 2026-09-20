class_name CommandLine


static func has_nomusic() -> bool:
	return OS.get_cmdline_user_args().has("--nomusic")


static func has_nosound() -> bool:
	return OS.get_cmdline_user_args().has("--nosound")
