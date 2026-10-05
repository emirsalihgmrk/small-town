extends SceneTree
## Bir sahnenin önizleme ekran görüntüsünü PNG olarak kaydeder (headless çalışmaz, pencere gerekir).
## Kullanım:
##   godot --path . --resolution 1920x1080 --script res://tools/screenshot.gd -- <sahne.tscn> <çıktı.png>
## Varsayılan: res://scenes/main/home.tscn -> res://previews/home.png

const DEFAULT_SCENE: String = "res://scenes/main/home.tscn"
const DEFAULT_OUTPUT: String = "res://previews/home.png"
## Yerleşim ve SVG içe aktarımlarının oturması için beklenecek kare sayısı.
const SETTLE_FRAMES: int = 10


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	var output_path: String = args[1] if args.size() > 1 else DEFAULT_OUTPUT
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Sahne yüklenemedi: %s" % scene_path)
		quit(1)
		return
	root.add_child(scene.instantiate())
	_capture.call_deferred(output_path)


func _capture(output_path: String) -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var err: Error = image.save_png(output_path)
	if err != OK:
		push_error("PNG kaydedilemedi: %s (%s)" % [output_path, error_string(err)])
	quit(err)
