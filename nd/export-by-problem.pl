write_annotated_formula(Label,Status,Formula) :-
	write('fof('),
	write(Label),
	write(','),
	write(Status),
	write(','),
	write('('),
	portray(Formula),
	write(')'),
	write(').').
export_assumptions(_,[]).
export_assumptions([Assumption|More]) :-
	fof(Assumption,Status,Formula,_,_),!,
	write_annotated_formula(Assumption,Status,Formula),
	nl,
	export_assumptions(More).
export_by_step(ByStep) :-
	fof(ByStep,_,Formula,inference(mizar_by,_,Assumptions),_),
	open(ByStep,write,ProblemStream),
	set_output(ProblemStream),
	write_annotated_formula(ByStep,'conjecture',Formula),
	nl(ProblemStream),
	export_assumptions(Assumptions),
	close(ProblemStream).
print_assumptions([]).
print_assumptions([H|T]) :-
	fof(H,_,Formula,_,_),
	write(Formula),
	nl,
	print_assumptions(T).
print_by_step_assumptions(ByStep) :-
	fof(ByStep,_,_,inference(mizar_by,_,Assumptions),_),
	print_assumptions(Assumptions).
