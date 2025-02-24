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

	trap                = 0xE0,
	emit                = 0xE1,

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

	static assert(__traits(hasMember, thelx.vm.isa, inName), "Missing struct `", inName, "`.");
	static if (__traits(hasMember, thelx.vm.isa, inName)) {
		alias InstructionType = __traits(getMember, thelx.vm.isa, inName);
	}
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

alias HeapPointer = void*;
alias Program = const(ubyte)[];
alias ProgramCounter = size_t;
alias SymbolTablePointer = size_t;
alias StackOffset = ushort;

struct HeapAddress {
	HeapPointer pointer;
}

struct ProgramAddress {
	ProgramCounter offset;
}

struct StackAddress {
	StackOffset offset;
}

struct SymbolAddress {
	SymbolTablePointer index;
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
	StackAddress target;
	StackAddress sourcePointer;
}

struct StoreInstruction {
	StackAddress targetPointer;
	StackAddress source;
}

struct PushInstruction {
	StackAddress source;
}

struct PopInstruction {
}

struct JumpAlwaysInstruction {
	ProgramAddress target;
}

struct JumpNonNegativeInstruction {
	ProgramAddress target;
	StackAddress subject;
}

struct JumpNonZeroInstruction {
	ProgramAddress target;
	StackAddress subject;
}

struct UnaryLogicalNotInstruction {
	ProgramAddress result;
	StackAddress subject;
}

struct UnaryNegativeInstruction {
	ProgramAddress result;
	StackAddress subject;
}

struct UnaryIncrementInstruction {
	ProgramAddress result;
	StackAddress subject;
}

struct UnaryDecrementInstruction {
	ProgramAddress result;
	StackAddress subject;
}

struct UnaryBitwiseNotInstruction {
	ProgramAddress result;
	StackAddress subject;
}

struct BinaryAndInstruction {
	StackAddress result;
	StackAddress operandA;
	StackAddress operandB;
}

struct BinaryOrInstruction {
	StackAddress result;
	StackAddress operandA;
	StackAddress operandB;
}

struct BinaryXorInstruction {
	StackAddress result;
	StackAddress operandA;
	StackAddress operandB;
}

struct BinaryAddInstruction {
	StackAddress sum;
	StackAddress operandA;
	StackAddress operandB;
}

struct BinarySubInstruction {
	StackAddress difference;
	StackAddress minuend;
	StackAddress subtrahend;
}

struct BinaryMulInstruction {
	StackAddress product;
	StackAddress multiplicand;
	StackAddress multiplier;
}

struct BinaryDivInstruction {
	StackAddress quotient;
	StackAddress dividend;
	StackAddress divisor;
}

struct BinaryModInstruction {
	StackAddress remainder;
	StackAddress dividend;
	StackAddress divisor;
}

struct BinaryShiftLeftInstruction {
	StackAddress result;
	StackAddress subject;
	StackAddress shift;
}

struct BinaryShiftRightInstruction {
	StackAddress result;
	StackAddress subject;
	StackAddress shift;
}

struct BinaryUShiftRightInstruction {
	StackAddress result;
	StackAddress subject;
	StackAddress shift;
}

struct TrapInstruction {
	SymbolAddress exceptionType;
	ProgramAddress handler;
}

struct EmitInstruction {
	StackAddress exceptionPointer;
}

struct PrintInstruction {
}

struct ErrorInstruction {
	StackAddress messagePointer;
}

struct CrashInstruction {
}

alias InstructionTypes = AliasSeq!(
	BadInstruction,
	NoDuplicates!instructionTable,
);

///
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

private ProgramAddress fetchTypedParameter(T : ProgramAddress)(ref Program program) {
	const value = fetchParameter!(typeof(ProgramAddress.offset))(program);
	return ProgramAddress(value);
}

private StackAddress fetchTypedParameter(T : StackAddress)(ref Program program) {
	const value = fetchParameter!(typeof(StackAddress.offset))(program);
	return StackAddress(value);
}

private SymbolAddress fetchTypedParameter(T : SymbolAddress)(ref Program program) {
	const value = fetchParameter!(typeof(SymbolAddress.index))(program);
	return SymbolAddress(value);
}

private auto decodeInstructionImpl(OpCode opCode)(ref Program program) {
	alias InstrType = InstructionType!(opCode);

	InstrType result;

	// dfmt off
	static foreach (paramName; FieldNameTuple!InstrType) {{
		alias paramType = typeof(__traits(getMember, InstrType, paramName));
		__traits(getMember, result, paramName) = fetchTypedParameter!paramType(program);
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
