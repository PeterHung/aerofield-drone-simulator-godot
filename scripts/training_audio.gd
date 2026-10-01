class_name TrainingAudio
extends Node
## Local synthesized audio and operating-system TTS. No microphone/network.
var effects_enabled = false
var music_enabled = false
var voice_enabled = false
var focused = true
var voice_status = ""
var voice_id = ""
var motor: AudioStreamPlayer
var music: AudioStreamPlayer
var tone: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_time = 0.0
var motor_phase = 0.0
var music_phase = 0.0
var motor_level = 0.0
var motor_frequency = 80.0
var music_time = 0.0
const SAMPLE_RATE = 22050.0

func _ready() -> void:
	motor = make_generator(-21)
	if motor.playing:
		playback = motor.get_stream_playback()
	music = make_generator(-27)
	tone = AudioStreamPlayer.new()
	tone.volume_db = -15
	add_child(tone)
	refresh_voices()

func refresh_voices() -> void:
	if DisplayServer.get_name() != "headless":
		var voices = DisplayServer.tts_get_voices_for_language("zh")
		if not voices.is_empty():
			voice_id = voices[0]
			for voice in DisplayServer.tts_get_voices():
				if str(voice.get("language","")).to_lower().contains("tw"):
					voice_id = voice.id
					break
	voice_status = "中文語音可用" if not voice_id.is_empty() else "系統未提供中文語音"

func make_generator(volume: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.08
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_db = volume
	add_child(player)
	if DisplayServer.get_name() != "headless":
		player.play()
	return player

func update_flight(sim: FlightSimulator) -> void:
	motor_level = 1.0 if sim.flight.armed and not sim.paused and sim.phase in ["active","declaration","awaitingEnd"] else 0.0
	motor_frequency = 78.0 + Vector2(sim.flight.v.x,sim.flight.v.z).length()*9.0 + absf(sim.flight.v.y)*12.0

func _process(_dt: float) -> void:
	if playback == null:
		return
	var count = playback.get_frames_available()
	var motor_frames = PackedVector2Array()
	motor_frames.resize(count)
	for i in range(count):
		motor_phase = fposmod(motor_phase+TAU*motor_frequency/SAMPLE_RATE,TAU)
		var value = (sin(motor_phase)*0.35+sin(motor_phase*2)*0.1)*motor_level if effects_enabled and focused else 0.0
		motor_frames[i] = Vector2(value,value)
	playback.push_buffer(motor_frames)
	var music_playback = music.get_stream_playback() as AudioStreamGeneratorPlayback
	count = music_playback.get_frames_available()
	var music_frames = PackedVector2Array()
	music_frames.resize(count)
	var notes = [261.63,329.63,392.0,329.63,293.66,349.23,440.0,349.23]
	for i in range(count):
		var note = notes[int(music_time/0.6)%notes.size()]
		music_phase = fposmod(music_phase+TAU*note/SAMPLE_RATE,TAU)
		var envelope = pow(maxf(0,1-fposmod(music_time,0.6)/0.6),2)
		var value = (sin(music_phase)*0.2+sin(music_phase*0.5)*0.1)*envelope if music_enabled and focused else 0.0
		music_frames[i] = Vector2(value,value)
		music_time += 1.0/SAMPLE_RATE
	music_playback.push_buffer(music_frames)

func beep(frequency: float = 660.0) -> void:
	if not effects_enabled or not focused:
		return
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	var samples = int(SAMPLE_RATE*0.12)
	var bytes = PackedByteArray()
	bytes.resize(samples*2)
	for i in range(samples):
		var value = sin(TAU*frequency*i/SAMPLE_RATE)*0.3*(1-float(i)/samples)
		bytes.encode_s16(i*2,int(value*32767))
	wav.data = bytes
	tone.stream = wav
	if DisplayServer.get_name() != "headless":
		tone.play()

func speak(message: String) -> void:
	if not voice_enabled or not focused or voice_id.is_empty() or DisplayServer.get_name() == "headless":
		return
	DisplayServer.tts_speak(message,voice_id,70,1.0,0.95,0,true)

func set_focused(value: bool) -> void:
	focused = value
	if not value:
		stop_voice()
		tone.stop()

func stop_voice() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()

func mute_all() -> void:
	effects_enabled = false
	music_enabled = false
	voice_enabled = false
	stop_voice()
	tone.stop()

func _exit_tree() -> void:
	stop_voice()
	if motor != null:
		motor.stop()
		motor.stream = null
	if music != null:
		music.stop()
		music.stream = null
	if tone != null:
		tone.stop()
		tone.stream = null
	playback = null
