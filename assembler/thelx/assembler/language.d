module thelx.assembler.language;

import std.ascii : toLower;
import thelx.vm.isa;

@safe:

///
struct _Instruction { //@suppress(dscanner.style.phobos_naming_convention)
	///
	string name;
}

alias Instruction = immutable(_Instruction);

///
static immutable Instruction[OpCode.max + 1] instructionTable = () {
	_Instruction[OpCode.max + 1] table;

	// init table
	table[] = Instruction(null);

	// dfmt off
	table[OpCode.invalid]           = Instruction(null);
	table[OpCode.noOp]              = Instruction("nop");

	table[OpCode.load]              = Instruction("load");
	table[OpCode.store]             = Instruction("store");

	table[OpCode.push]              = Instruction("push");
	table[OpCode.pop]               = Instruction("pop");

	table[OpCode.jumpAlways]        = Instruction("jal");
	table[OpCode.jumpNonNegative]   = Instruction("jnn");
	table[OpCode.jumpNonZero]       = Instruction("jnz");

	table[OpCode.unaryLogicalNot]   = Instruction("lneg");
	table[OpCode.unaryNegative]     = Instruction("numneg");
	table[OpCode.unaryIncrement]    = Instruction("inc");
	table[OpCode.unaryDecrement]    = Instruction("dec");
	table[OpCode.unaryBitwiseNot]   = Instruction("bwneg");

	table[OpCode.binaryAnd]         = Instruction("and");
	table[OpCode.binaryOr]          = Instruction("or");
	table[OpCode.binaryXor]         = Instruction("xor");
	table[OpCode.binaryAdd]         = Instruction("add");
	table[OpCode.binarySub]         = Instruction("sub");
	table[OpCode.binaryMul]         = Instruction("mul");
	table[OpCode.binaryDiv]         = Instruction("div");
	table[OpCode.binaryMod]         = Instruction("mod");
	table[OpCode.binaryShiftLeft]   = Instruction("shl");
	table[OpCode.binaryShiftRight]  = Instruction("shr");
	table[OpCode.binaryUShiftRight] = Instruction("ushr");

	table[OpCode.trap]              = Instruction("trap");
	table[OpCode.emit]              = Instruction("emit");

	table[OpCode.print]             = Instruction("print");

	table[OpCode.error]             = Instruction("err");
	table[OpCode.crash]             = Instruction("crash");
	// dfmt on

	return table;
}();

/+
	Determines whether `needle[1 .. $]` matches `haystack` case-insensitively.
 +/
private pragma(inline, true) bool matches(string needle)(string haystack) @trusted {
	import std.string : toLower;

	static immutable eedle = needle[1 .. $].toLower();

	if (haystack.length != eedle.length) {
		return false;
	}

	static foreach (immutable idx, const c; eedle) {
		if (haystack.ptr[idx].toLower != c) {
			return false;
		}
	}

	return true;
}

///
OpCode assemble(string instruction) {
	if (instruction.length == 0) {
		return OpCode.invalid;
	}

	const nstruction = instruction[1 .. $];

	switch (instruction[0].toLower) {
		// dfmt off
		static foreach (firstLetter; 'a' .. ('z' + 1)) {
			case firstLetter: {
				static foreach (immutable OpCode opCode, const tableInstruction; instructionTable) {
					static if (
						(tableInstruction.name !is null) &&
						(tableInstruction.name[0] == firstLetter)
					) {
						if (nstruction.matches!(tableInstruction.name)()) {
							return opCode;
						}
					}
				}
			}
		}

		default:
			return OpCode.invalid;
		// dfmt on
	}
}

///
Instruction disassemble(OpCode opCode) {
	return instructionTable[opCode];
}

@safe unittest {
	import std.traits : EnumMembers;

	bool pass = true;

	assert(assemble(null) == OpCode.invalid);

	static foreach (opCode; EnumMembers!OpCode) {
		{
			enum isRelevant = (
					opCode != OpCode.min
						&& opCode != OpCode.max
						&& opCode != OpCode.invalid
				);
			static if (isRelevant && (disassemble(opCode).name is null)) {
				pragma(msg,
					"Failed to disassemble `", opCode, "`.",
					" Missing an entry in instructionTable?"
				);
				pass = false;
			}
		}
	}

	static foreach (OpCode opCode, Instruction instruction; instructionTable) {
		static if ((instruction.name !is null) && (assemble(instruction.name) != opCode)) {
			pragma(msg,
				"Failed to assemble instruction `", instruction.name, "`.",
				" Missing a switch-case?"
			);

			pass = false;
		}
	}

	assert(pass, "Check the pragma messages above for further details.");
}
