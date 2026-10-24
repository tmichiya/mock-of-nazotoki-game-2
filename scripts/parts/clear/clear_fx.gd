class_name ClearFx
extends Node2D
## クリアした時の演出の窓口。購読している「○○をクリア」が来たら、この場所でパーティクルを出して効果音を鳴らす。
## 効果音(stream)が空なら仮のチャイムを鳴らす。本番の音や絵ができたら、ここに設定するだけでよい。
## コードやシグナルから直接 play() を呼んでもよい。

signal played

## 購読するクリアの名前(どれかがクリアされるたびに鳴る)。空で listen_all もオフなら、play() を呼んだ時だけ
@export var listen: Array[StringName] = []
## どのクリアでも鳴らす(島全体の演出用)
@export var listen_all := false
## 鳴らす場所の高さ(段)。-1 なら置いた場所の地形の高さ
@export var fixed_level := -1

@export_group("パーティクル")
@export var particles_enabled := true
@export var particle_amount := 24
@export var particle_lifetime := 0.9
@export var particle_speed := 70.0
@export var particle_color := Color(1.0, 0.9, 0.45)
## 粒の絵(空なら四角い点)
@export var particle_texture: Texture2D
@export var particle_scale := 2.0

@export_group("効果音")
## 効果音(空なら仮のチャイム)
@export var stream: AudioStream
@export var volume_db := 0.0
## stream が空の時に仮のチャイムを鳴らす
@export var placeholder_chime := true

var _particles: CPUParticles2D
var _player: AudioStreamPlayer2D
var _synth: ToneSynth


func _ready() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 0.9
	_particles.amount = particle_amount
	_particles.lifetime = particle_lifetime
	_particles.direction = Vector2.UP
	_particles.spread = 180.0
	_particles.initial_velocity_min = particle_speed * 0.5
	_particles.initial_velocity_max = particle_speed
	_particles.gravity = Vector2(0, 90)
	_particles.scale_amount_min = particle_scale
	_particles.scale_amount_max = particle_scale
	_particles.color = particle_color
	if particle_texture:
		_particles.texture = particle_texture
	_particles.z_index = 95
	_particles.z_as_relative = false
	add_child(_particles)
	_player = AudioStreamPlayer2D.new()
	_player.volume_db = volume_db
	add_child(_player)
	_synth = ToneSynth.new()
	add_child(_synth)
	Clears.cleared.connect(_on_cleared)


func _on_cleared(name: StringName) -> void:
	if listen_all or name in listen:
		play()


## 演出を出す
func play() -> void:
	var h := float(fixed_level) if fixed_level >= 0 else World.height_at(global_position)
	_particles.position = World.height_offset(h + 0.5)
	if particles_enabled:
		_particles.restart()
		_particles.emitting = true
	if stream:
		_player.stream = stream
		_player.play()
	elif placeholder_chime:
		for i in range(3):
			get_tree().create_timer(0.09 * i).timeout.connect(_synth.play_note.bind([523.25, 659.25, 783.99][i], 0.4))
	played.emit()
