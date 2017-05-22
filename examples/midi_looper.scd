MIDIIn.connectAll;
(
////////////////////////////////////
//					SETUP					 //
////////////////////////////////////

// [Switch] Botón que inicia y corta el bucle
~btncompas = 2;

// [Switch] Botón que reproduce lo grabado
~btnplay = 21;

// [Trigger] Botón que vacía la pila
~btnclear = 22;

// Función que suena. Parámetros |num, vel, dur| en midi.
~soundfn = { |num, vel, dur|
	Synth(\default, [\freq, num.midicps]);
};

// Función que silencia el sonido.
~nosoundfn = { |return|
	return.free;
};

////////////////////////////////////
// 				CONTROL				 //
////////////////////////////////////
~cc.free;
~cc = MIDIFunc.cc({| val, num| case

	{ num == ~btncompas } {
		(val == 127).if({
			"Compás iniciado".postln;
			~startCompas.value;
		}, {
			~stopCompas.try;
		});
	}

	{ num == ~btnplay} {
		(val == 127).if({
			"Reproduciendo".postln;
			~play.value;
		}, {
			~stop.try;
		});
	}

	{ num == ~btnclear} {
		(val == 127).if({
			"Pila vaciada".postln;
			~miditraces = Array.new;
		});
	};
});

{~stop.value }.try;


/*	[num, vel, start, stop] */
~miditrace = Array.new;
~miditraces = Array.new;
~totaltime = 0;

{ ~notes.do({ |trace| trace[2].free }) }.try;
/*			[vel, start, sound] */
~notes = [0  , 0    , false]!128;

~time = TempoClock.new(1, 0);
//"current beats:" + time.beats;



~noteOn.free;
~noteOn = MIDIFunc.noteOn({ |vel, num|
	var sound = ~soundfn.value(num);
	~notes[num] = [vel, ~time.beats, sound];
});

~noteOff.free;
~noteOff = MIDIFunc.noteOff({ |val, num|
	var vel, start, sound, trace;

	vel = ~notes[num][0];
	start = ~notes[num][1];
	sound = ~notes[num][2];
	trace = [num, vel, start, ~time.beats];
	~nosoundfn.value(sound);
	~miditrace = ~miditrace.add(trace);
	~notes[num] = [0, 0];
});



~startCompas = {
	~time.beats = 0;
	~miditrace = Array.new;
	//~notes = [0  , 0    ]!128;
};

~stopCompas = {
	if( ~miditrace.size > 0, {
		~totaltime = ~time.beats;
		("Total time: " + ~totaltime).postln;
		~miditraces = ~miditraces.add(~miditrace);
		~miditrace = Array.new;
		"Compás agregado".postln;
	});
};



////////////////////////////////////
// 			REPRODUCCIÓN			 //
////////////////////////////////////

~runTask = {
	var silence = 0;

	~miditraces.do({ |miditrace|
		Task.new({
			miditrace.do({ |trace|
				var
				num = trace[0],
				vel = trace[1],
				start = trace[2],
				stop = trace[3];

				// tiempo entre nota y nota
				(start-silence).wait;

				Task.new({
					var
					dur = (stop-start),
					synth = ~soundfn.value(num, vel, dur);

					// tiempo de cada nota
					dur.wait;

					~nosoundfn.value(synth);
				}).start;

				silence = start;

			});
		}).play;
	});
};

~play = {
	~player = Task.new({
		inf.do({
			~runTask.value;
			~startCompas.value;
			~totaltime.wait;
			~stopCompas.try;
		});
	});
	~player.start;
};

~stop = {
	~player.stop;
};

"\nPresiona " + ~btncompas + " para iniciar el bucle.\nPresiona " + ~btnplay + " para reproducir el bucle.";
)