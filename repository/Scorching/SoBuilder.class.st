"
I provide an API to build basic blocks and instructions.

Instance Variables
	codeNode:		<AbsCode>
	currentBasicBlock:		<BasicBlock> BasicBlock I am adding instruction to while building instructions.
	returnBasicBlock <BasicBlock> basicblock created specifically to hold the unique return instruction of the method.
	currentInstr: <Instruction> last instruction I added or nil if the currentBasicBlock has no instructions. 

"
Class {
	#name : #SoBuilder,
	#superclass : #Object,
	#instVars : [
		'codeNode',
		'currentBasicBlock',
		'returnBasicBlock',
		'currentInstr'
	],
	#category : #'Scorching-Decompiler'
}

{ #category : #'instance creation' }
SoBuilder class >> on: codeNodeClass [
	^ self basicNew
		codeNode: codeNodeClass new;
		initialize;
		yourself
]

{ #category : #'adding instructions' }
SoBuilder >> addCFGInstr: instr [
	currentBasicBlock lastInstr: instr.
	^ self addInstr: instr
]

{ #category : #building }
SoBuilder >> addFakeConstant: cst fakeBasicBlock: bb [
	returnBasicBlock firstInstr addInput: cst basicBlock: bb.
]

{ #category : #'adding instructions' }
SoBuilder >> addInstr: instr [
	currentInstr 
		ifNotNil: [ currentInstr nextInstr: instr ]
		ifNil: [ currentBasicBlock firstInstr: instr ].
	^ currentInstr := instr
]

{ #category : #'building-immediate' }
SoBuilder >> arg: index [
	^ SoArg new 
		index: index;
		yourself
]

{ #category : #building }
SoBuilder >> array: values [
	| init |
	init := self addInstr: ((SoPointerNewColon new
		behavior: Array) 
		sized: (SoConstant constant: values size);
		yourself).
	init	needsInit: false.
	values withIndexDo: [ :val :i |
		self addInstr: (SoPointerWrite new 
			object: init;
			index: (SoConstant constant: i);
			expression: val;
			storeCheck: false;
			yourself) ].
	^ init
]

{ #category : #building }
SoBuilder >> backjump: basicBlock [
	^  self addCFGInstr: (SoSmalltalkBackjump 
		from: currentBasicBlock
		to: basicBlock)
]

{ #category : #building }
SoBuilder >> backjump: basicBlock class: class [
	^  self addCFGInstr: (class 
		from: currentBasicBlock
		to: basicBlock)
]

{ #category : #accessing }
SoBuilder >> branch: expression [
	^ self addCFGInstr: (SoSmalltalkBooleanBranch new 
		expression: expression;
		yourself)
]

{ #category : #accessing }
SoBuilder >> codeNode [
	<generated>
	^ codeNode
]

{ #category : #accessing }
SoBuilder >> codeNode: aValue [
	<generated>
	codeNode := aValue
]

{ #category : #'building-immediate' }
SoBuilder >> constant: cst [
	^ SoConstant new 
		constant: cst;
		yourself
]

{ #category : #building }
SoBuilder >> context [
	self flag: #TODO.
	^ SoConstant new constant: #thisContext; yourself
]

{ #category : #building }
SoBuilder >> contextInstVar: index of: object [
	^ self addInstr: (SoMaybeContextPointerRead new
		index: (SoConstant constant: index + 1);
		object: object;
		yourself)
]

{ #category : #building }
SoBuilder >> createTempVector: size [
	^ self addInstr: (SoPointerNewColon new
		behavior: Array;
		sized: (SoConstant constant: size);
		yourself).
]

{ #category : #accessing }
SoBuilder >> currentBasicBlock [
	<generated>
	^ currentBasicBlock
]

{ #category : #accessing }
SoBuilder >> currentBasicBlock: aValue [
	<generated>
	currentBasicBlock := aValue
]

{ #category : #accessing }
SoBuilder >> currentInstr [
	<generated>
	^ currentInstr
]

{ #category : #accessing }
SoBuilder >> currentInstr: aValue [
	<generated>
	currentInstr := aValue
]

{ #category : #decompilation }
SoBuilder >> fillPhi: firstPhi withValues: predecessors [ 
	| instr index |
	instr := firstPhi.
	index := 1.
	[ instr notNil and: [ instr isPhi ] ] whileTrue: [ 
		[ predecessors allSatisfy: [ :pred | (pred tempData at: index) isTempVector ] 
			] whileTrue: [ index := index + 1 ]. "no phis for temp vectors"
		predecessors do: [ :pred | instr addInput: (pred tempData at: index) basicBlock: pred ].
		index := index + 1.
		instr := instr nextInstr ].
]

{ #category : #building }
SoBuilder >> fullBlock: compiledBlock receiver: rcvr copiedValues: copiedValues class: closureClass [
	^ self addInstr: (closureClass new
		values: copiedValues;
		receiver: rcvr;
		compiledCode: compiledBlock;
		yourself)
	
]

{ #category : #building }
SoBuilder >> global: assoc [
	^ self addInstr: (SoPointerRead new
		object: (self innerGlobal: assoc);
		index: (SoConstant constant: 2);
		type: (SoSingleHintType for: assoc value class);
		yourself)
]

{ #category : #building }
SoBuilder >> indirectTemp: remoteTempIndex vector: varHolder [
	^ self addInstr: (SoPointerRead new
		index: (SoConstant constant: remoteTempIndex + 1);
		object: varHolder;
		yourself)
]

{ #category : #initialization }
SoBuilder >> initialize [

	super initialize.

	"build the last basicBlock"
	currentBasicBlock := returnBasicBlock := SoBasicBlock new.
	self return: self phi level: codeNode returnToSenderLevel.

	"superBB entry"
	self switchToBasicBlock: SoBasicBlock new.
]

{ #category : #'building-support' }
SoBuilder >> innerGlobal: assoc [
	| litR |
	litR := self addInstr: (SoMutableLiteralRead new 
		type: (SoSingleHintType for: assoc class);
		literal: assoc;
		yourself).
	^ self addInstr: (SoUnforwardNonImmediate new
		expression: litR;
		yourself)
]

{ #category : #building }
SoBuilder >> instVar: index of: object [
	^ self addInstr: (SoPointerRead new
		index: (SoConstant constant: index + 1);
		object: object;
		yourself)
]

{ #category : #building }
SoBuilder >> jump: basicBlock [
	^  self addCFGInstr: (SoJumpAhead from: currentBasicBlock to: basicBlock)
]

{ #category : #building }
SoBuilder >> localReturn: instr [
	returnBasicBlock firstInstr addInput: instr basicBlock: currentBasicBlock.
	self jump: returnBasicBlock.
]

{ #category : #building }
SoBuilder >> loopHead [
	^ self addInstr: SoLoopHead new
]

{ #category : #building }
SoBuilder >> mutableLiteral: lit [
	^ self addInstr: (SoMutableLiteralRead new
		literal: lit;
		type: (SoSingleHintType for: lit class);
		yourself)
]

{ #category : #building }
SoBuilder >> nonLocalReturn: value [
	^  self addCFGInstr: (SoReturn new
		returnedValue: value;
		numLevels: 2;
		yourself)
]

{ #category : #building }
SoBuilder >> phi [
	^ self addInstr: SoPhi new
]

{ #category : #building }
SoBuilder >> pointerEquals: rcvr with: arg [
	^ self addInstr: (SoRawPointerEqualsOp 
		withReceiver: (self unforwardOp: rcvr)
		arguments: {self unforwardOp: arg})
]

{ #category : #accessing }
SoBuilder >> rawBranch: expression [
	^ self addCFGInstr: (SoPipelinedBooleanBranch new 
		expression: expression;
		yourself)
]

{ #category : #'building-immediate' }
SoBuilder >> receiver [
	^ SoReceiver new
]

{ #category : #initialization }
SoBuilder >> return: instr level: level [
	^ self addCFGInstr: (SoReturn new
		returnedValue: instr;
		numLevels: level;
		yourself)
]

{ #category : #accessing }
SoBuilder >> returnBasicBlock [
	<generated>
	^ returnBasicBlock
]

{ #category : #accessing }
SoBuilder >> returnBasicBlock: aValue [
	<generated>
	returnBasicBlock := aValue
]

{ #category : #accessing }
SoBuilder >> returnPhi [
	^ returnBasicBlock firstInstr
]

{ #category : #decompilation }
SoBuilder >> saveLiveVariables: array [
	currentBasicBlock tempData: array
]

{ #category : #building }
SoBuilder >> send: selector receiver: rcvr args: args [
	^ self addInstr: (SoSend new 	
		receiver: rcvr;
		arguments: args;
		selector: selector;
		yourself)
]

{ #category : #building }
SoBuilder >> store: val contextInstVar: index of: object [
	^ self addInstr: (SoMaybeContextPointerWrite new
		index: (SoConstant constant: index + 1);
		object: object;
		expression: val;
		yourself)
]

{ #category : #building }
SoBuilder >> store: val global: assoc [
	^ self addInstr: (SoReadOnlyCheckPointerWrite new
		object: (self innerGlobal: assoc);
		index: (SoConstant constant: 2);
		expression: val;
		yourself)
]

{ #category : #building }
SoBuilder >> store: val indirectTemp: remoteTempIndex vector: varHolder [
	^ self addInstr: (SoPointerWrite new
		index: (SoConstant constant: remoteTempIndex + 1);
		object: varHolder;
		expression: val;
		yourself)
]

{ #category : #building }
SoBuilder >> store: val instVar: index of: object [
	^ self addInstr: (SoReadOnlyCheckPointerWrite new
		index: (SoConstant constant: index + 1);
		object: object;
		expression: val;
		yourself)
]

{ #category : #decompilation }
SoBuilder >> switchBackToBasicBlock: basicBlock [
	codeNode basicBlocks removeLast.
	currentBasicBlock := basicBlock.
	currentInstr := basicBlock lastInstr prevInstr.
	basicBlock lastInstr: nil.
]

{ #category : #decompilation }
SoBuilder >> switchToBasicBlock: basicBlock [
	currentBasicBlock lastInstr ifNil: [ self jump: basicBlock ].
	currentBasicBlock := basicBlock.
	currentInstr := nil.
	codeNode addBasicBlock: basicBlock
]

{ #category : #decompilation }
SoBuilder >> terminate [
	returnBasicBlock firstInstr inputs ifEmpty: [ ^ codeNode ].
	codeNode addBasicBlock: returnBasicBlock.
	SoBasicBlockMerger new mergeIntoPredecessorIfPossible: returnBasicBlock.
	^ codeNode  
]

{ #category : #'building-support' }
SoBuilder >> unforwardOp: op [
	^ self addInstr: (SoUnforward new
		expression: op;
		yourself)
]
