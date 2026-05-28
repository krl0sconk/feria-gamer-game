extends Marker2D

## Si false, BullySpawnManager ignora este punto (útil junto a bullies scriptados).
@export var enabled: bool = true

# Perfil opcional para este punto de spawn. Si está vacío, usa el perfil dado
# por el BullySpawnManager o el DEFAULT_PROFILE.
@export var profile_id: String = ""

# Diálogo y resultado opcionales para este bully. Si quedan vacíos, el
# BullySpawnManager aplica sus valores por defecto.
@export_file("*.json") var dialogue_json_path: String = ""
@export var intro_dialogue_id: String = ""
@export var win_dialogue_id: String = ""
@export var lose_dialogue_id: String = ""

# Escena de batalla y comportamiento post-victoria opcionales.
@export var battle_scene: PackedScene = null
@export var despawn_on_win: bool = true

# Voz opcional del diálogo.
@export var dialogue_voice: AudioStream = null

# Permite asignar un SpriteFrames específico desde el Inspector para este
# punto de spawn; si es null, el spawner usará la tabla PROFILE_FRAMES.
@export var sprite_frames: SpriteFrames = null

# Chart específico para este bully. Si está vacío, el spawner usa el default.
@export_file("*.json") var battle_chart_path: String = ""

# Canción específica para la batalla de este bully en battle.tscn.
# Si es null, se usa la música por defecto de la escena de batalla.
@export var battle_music: AudioStream = null

# Escala del AnimatedSprite2D (walk 16x32 ~ Vector2(4, 4); batalla FNF ~ 0.1).
@export var sprite_scale: Vector2 = Vector2(4, 4)

# Animación inicial preferida (p. ej. "frente" para NPCs top-down).
@export var preferred_animation: String = "frente"
