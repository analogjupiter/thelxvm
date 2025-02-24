/++
	Instruction set architecture
 +/
module thelx.vm.isa;

import std.meta;
import std.sumtype;
import std.traits;
import thelx.util;

@safe pure nothrow @nogc:

///
enum OpCode : ubyte {
	// dfmt off
	invalid             = 0x00,
	noOp                = 0x01,

	load                = 0x03,
	store               = 0x04,

	push                = 0x08,
	pop                 = 0x09,

	jumpAlways          = 0x10,
	jumpNonNegative     = 0x11,
	jumpNonZero         = 0x12,

	unaryLogicalNot     = 0x20,
	unaryNegative       = 0x21,
	unaryIncrement      = 0x22,
	unaryDecrement      = 0x23,
	unaryBitwiseNot     = 0x24,

	binaryAnd           = 0x40,
	binaryOr            = 0x41,
	binaryXor           = 0x42,
	binaryAdd           = 0x43,
	binarySub           = 0x44,
	binaryMul           = 0x45,
	binaryDiv           = 0x46,
	binaryMod           = 0x47,
	binaryShiftLeft     = 0x48,
	binaryShiftRight    = 0x49,
	binaryUShiftRight   = 0x4A,

	print               = 0xFD,

	error               = 0xFE,
	crash               = 0xFF,

	// dfmt on
}

static assert(OpCode.min == 0x00);
static assert(OpCode.max == 0xFF);

/++
	Corresponding enum member to an op-code (as `AliasSeq`).
 +/
private template InstructionOpCodeMember(OpCode opCode) {
	alias InstructionOpCodeMember = AliasSeq!();
	static foreach (member; EnumMembers!OpCode) {
		static if (mixin(member) == opCode) {
			InstructionOpCodeMember = AliasSeq!(member);
		}
	}
}

/++
	Identifier of the corresponding enum member to an op-code.
 +/
private template instructionIdentifier(OpCode opCode) {
	static if (InstructionOpCodeMember!opCode.length == 1)
		enum instructionIdentifier = __traits(identifier, InstructionOpCodeMember!opCode);
	else
		enum instructionIdentifier = "invalid";
}

@safe unittest {
	assert(instructionIdentifier!(OpCode.invalid) == "invalid");
	assert(instructionIdentifier!(cast(OpCode) 2) == "invalid");
	assert(instructionIdentifier!(OpCode.noOp) == "noOp");
}

/++
	The corresponding `Instruction` type to the provided op-code.
 +/
private template InstructionType(OpCode opCode) {
	import std.ascii : toUpper;

	private enum string opName = instructionIdentifier!opCode;
	private enum string inName = opName[0].toUpper ~ opName[1 .. $] ~ "Instruction";

	alias InstructionType = __traits(getMember, thelx.vm.isa, inName);
}

@safe unittest {
	assert(is(InstructionType!(OpCode.invalid) == InvalidInstruction));
	assert(is(InstructionType!(cast(OpCode) 2) == InvalidInstruction));
	assert(is(InstructionType!(OpCode.noOp) == NoOpInstruction));
}

/++
	AliasSeq of all possible OpCode values (i.e. numbers from 0 .. 255+1)
 +/
private template OpCodesSeq() {
	alias OpCodesSeq = AliasSeq!();
	static foreach (n; OpCode.min .. OpCode.max + 1) {
		OpCodesSeq = AliasSeq!(OpCodesSeq, cast(OpCode) n);
	}

	static assert(OpCodesSeq.length == 256);
}

/++
	Maps op-codes to their corresponding `Instruction` type.
 +/
alias instructionTable = staticMap!(InstructionType, OpCodesSeq!());

///
@safe unittest {
	assert(is(instructionTable[OpCode.invalid] == InvalidInstruction));
	assert(is(instructionTable[cast(OpCode) 2] == InvalidInstruction));
	assert(is(instructionTable[OpCode.noOp] == NoOpInstruction));
}

alias Program = const(ubyte)[];
alias ProgramCounter = size_t;
alias StackOffset = ushort;
alias HeapPointer = void*;

struct StackAddress {
	StackOffset offset;
}

struct HeapAddress {
	HeapPointer pointer;
}

struct BadInstruction {
	OpCode opCode;
	size_t parametersExpected;
	size_t parametersFound;
}

struct InvalidInstruction {
}

struct NoOpInstruction {
}

struct LoadInstruction {
	StackAddress sourcePointer;
	StackAddress target;
}

struct StoreInstruction {
	StackAddress source;
	StackAddress targetPointer;
}

struct PushInstruction {
	StackAddress source;
}

struct PopInstruction {
}

struct JumpAlwaysInstruction {
}

struct JumpNonNegativeInstruction {
}

struct JumpNonZeroInstruction {
}

struct UnaryLogicalNotInstruction {
}

struct UnaryNegativeInstruction {
}

struct UnaryIncrementInstruction {
}

struct UnaryDecrementInstruction {
}

struct UnaryBitwiseNotInstruction {
}

struct BinaryAndInstruction {
}

struct BinaryOrInstruction {
}

struct BinaryXorInstruction {
}

struct BinaryAddInstruction {
}

struct BinarySubInstruction {
}

struct BinaryMulInstruction {
}

struct BinaryDivInstruction {
}

struct BinaryModInstruction {
}

struct BinaryShiftLeftInstruction {
}

struct BinaryShiftRightInstruction {
}

struct BinaryUShiftRightInstruction {
}

struct PrintInstruction {
}

struct ErrorInstruction {
}

struct CrashInstruction {
}

alias InstructionTypes = AliasSeq!(
	BadInstruction,
	NoDuplicates!instructionTable,
);

alias Instruction = SumType!(InstructionTypes);

private OpCode fetchOpCode(ref Program program) {
	const op = program[0].castTo!OpCode;
	program = program[1 .. $];
	return op;
}

private T fetchParameter(T)(ref Program program) @trusted {
	const param = program
		.castTo!(const(void)[])[0 .. T.sizeof]
		.castTo!(T[])[0];

	program = program[T.sizeof .. $];

	return param;
}

private StackAddress fetchStackAddressParameter(ref Program program) {
	const value = fetchParameter!(typeof(StackAddress.offset))(program);
	return StackAddress(value);
}

private auto decodeInstructionImpl(OpCode opCode)(ref Program program) {
	alias InstrType = InstructionType!(opCode);

	InstrType result;

	// dfmt off
	static foreach (paramName; FieldNameTuple!InstrType) {{
		alias param = __traits(getMember, InstrType, paramName);
		alias paramType = typeof(param);

		static if (is(paramType == StackAddress)) {
			__traits(getMember, result, paramName) = fetchStackAddressParameter(program);
		}
	}}
	// dfmt on

	return result;
}

private Instruction decodeInstructionImpl(ref Program program) {
	const opCode = program.fetchOpCode();

	switch (opCode) {
		// dfmt off
		static foreach (oc; EnumMembers!OpCode) {
			case oc:
				return Instruction(decodeInstructionImpl!oc(program));
		}

		default:
			goto case OpCode.invalid;
		// dfmt on
	}
}

size_t decodeInstruction(Program program, out Instruction result) {
	const initialProgramLength = program.length;

	() @trusted { result = decodeInstructionImpl(program); }();

	const bytesDecoded = initialProgramLength - program.length;
	return bytesDecoded;
}

struct InstructionDecoder {
	private {
		Program _program;
		ProgramCounter _pc;
		Instruction _front;
	}

@safe pure nothrow @nogc:

	public this(Program program) {
		this.loadProgram(program);
	}

	Program dumpProgram() const {
		return _program;
	}

	ProgramCounter programCounter() const {
		return _pc;
	}

	void loadProgram(Program program) {
		_program = program;
		_pc = 0;
	}

	bool empty() const {
		return (_pc >= _program.length);
	}

	Instruction front() const {
		return _front;
	}

	void popFront() {
		const bytesDecoded = _program.decodeInstruction(_front);
		_pc += bytesDecoded;
	}
}
