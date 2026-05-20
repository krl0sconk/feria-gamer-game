extends Marker2D

# Perfil opcional para este punto de spawn. Si está vacío, usa el perfil dado
# por el BullySpawnManager o el DEFAULT_PROFILE.
@export var profile_id: String = ""

# Permite asignar un SpriteFrames específico desde el Inspector para este
# punto de spawn; si es null, el spawner usará la tabla PROFILE_FRAMES.
@export var sprite_frames: SpriteFrames = null

# Chart específico para este bully. Si está vacío, el spawner usa el default.
@export_file("*.json") var battle_chart_path: String = ""

# Canción específica para la batalla de este bully en battle.tscn.
# Si es null, se usa la música por defecto de la escena de batalla.
@export var battle_music: AudioStream = null
