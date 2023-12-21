/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

export 'package:tekaly_music_note/src/chord_pattern.dart'
    show
        ChordPattern,
        minorAdd9,
        major,
        majorAdd9,
        major6,
        major6_9,
        major7,
        major7M,
        major7_b5,
        major7_b9,
        major7_sharp5,
        major9,
        major9M,
        major_b5,
        major9_b5,
        major11,
        major13,
        minor,
        minor6,
        minor6_9,
        minor7,
        minor7M,
        minor7_b5,
        minor7_b9,
        minor9,
        minor11,
        minor13,
        dim,
        dim7,
        aug,
        sus2,
        sus4,
        sevenSus4;
export 'package:tekaly_music_note/src/chord_pattern.dart'
    show ChordPattern, checkChordPattern, allPatterns;
export 'package:tekaly_music_note/src/interval.dart'
    show
        root,
        Interval,
        RawInterval,
        minor2nd,
        major2nd,
        minor3rd,
        major3rd,
        perfect4th,
        perfect5th,
        perfectFifth,
        minor6th,
        major6th,
        minor7th,
        major7th,
        minor9th,
        major9th,
        major13th,
        octave,
        perfect11th,
        seventhFlatFlat,
        fifthFlat,
        fifthSharp,
        tritone;
export 'package:tekaly_music_note/src/key.dart'
    show
        Key,
        KeyExtension,
        c,
        d,
        e,
        f,
        g,
        a,
        b,
        cSharp,
        dSharp,
        fSharp,
        gSharp,
        aSharp,
        dFlat,
        eFlat,
        gFlat,
        aFlat,
        bFlat,
        allKeys,
        allAlteredKeys,
        allUnalteredKeys,
        KeyListExtension;
export 'package:tekaly_music_note/src/names.dart'
    show
        chordPatternNames,
        flatKeyNames,
        sharpKeyNames,
        keyNames,
        intervalLongNames,
        intervalShortNames,
        tryParseKey,
        tryParseChordPattern,
        tryParseChord;
export 'package:tekaly_music_note/src/note.dart'
    show
        Note,
        c0,
        a2,
        a3,
        a4,
        c2,
        d2,
        e2,
        g2,
        b2,
        c3,
        d3,
        e3,
        fSharp3,
        g3,
        b3,
        c4,
        d4,
        e4,
        e5;

export 'src/chord.dart' show Chord, ChordExtension, ChordListExtension;
export 'src/octave.dart' show octaveNoteCount, semitonesInOctave;
export 'src/semitones_base.dart' show SemitonesBase;
export 'src/utils.dart' show intervalSimilar, positiveKeyDiff, semitonesSameKey;
