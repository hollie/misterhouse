
These files are used by the Eliza chatbox program.

See mh/code/Bruce/speak_server.pl for an example.


Format of the script file
    This module includes a default script file within itself, so it
    is not necessary to explicitly specify a script file when
    instantiating an Eliza object.

    Each line in the script file can specify a key, a decomposition
    rule, or a reassembly rule.

      key: remember 5
        decomp: * i remember *
          reasmb: Do you often think of (2) ?
          reasmb: Does thinking of (2) bring anything else to mind ?
        decomp: * do you remember *
          reasmb: Did you think I would forget (2) ?
          reasmb: What about (2) ?
          reasmb: goto what
      pre: equivalent alike
      synon: belief feel think believe wish

    The number after the key specifies the rank. If a user's input
    contains the keyword, then the transform() function will try to
    match one of the decomposition rules for that keyword. If one
    matches, then it will select one of the reassembly rules at
    random. The number (2) here means "use whatever set of words
    matched the second asterisk in the decomposition rule."

    If you specify a list of synonyms for a word, the you should use
    a "@" when you use that word in a decomposition rule:

      decomp: * i @belief i *
        reasmb: Do you really think so ?
        reasmb: But you are not sure you (3).

    Otherwise, the script will never check to see if there are any
    synonyms for that keyword.

    Reassembly rules should be marked with *reasm_for_memory* rather
    than *reasmb* when it is appropriate for use when a user's
    comment has been extracted from memory.

      key: my 2
        decomp: * my *
          reasm_for_memory: Let's discuss further why your (2).
          reasm_for_memory: Earlier you said your (2).
          reasm_for_memory: But your (2).
          reasm_for_memory: Does that have anything to do with the fact that your (2) ?

