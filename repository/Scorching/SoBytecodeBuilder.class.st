"
I am used in a 2-step process to generate compiledMethod/CompiledBlock out of the Method/Block.

1. I am called to generate the bytecodes of each basicblock based on the current instructions they hold. I use the the encoder to do so, and I store each basic block bytecodes in their tempData field.

2. I then generate the jumps iteratively with the correct size, the compiled method header and generate the method by merging the basicblock bytecodes.

	encoder <Encoder> abstract layer over the bytecode set
	referenceTranslator <ReferenceTranslator> to translate intructions referenced by instructions generated.
	literals < OrderedCollection of literals> all the optimized method literals. 
	numTemps <Smi> numTemps of the optimized method 
	numCopied <Smi> numCopied of the current closure
	numStack <Smi> max num stack slots used to know if a large frame is needed
	basicBlocks <Collection of basicBlocks> basic blocks of the method / closure I generate
	deoptMapping <Collection of basicBlock -> (pc in basicBlock -> deoptReference) then during the process the pc is switched to the gobal pc (pc from method initialPC)
	blockOuterMapping <DeoptDictionary of (compiledBlock -> ctxtMarker> Used to remap block outer contexts.
	extraTempIndex <smi> temp index for backend extra assignments, usually to handle issues with bytecode encoding related to constant instance variable access.
	assignedTempIndexes <Set of smi> temp indexes that have already been assigned. Used to avoid nil assignment on uninitialized temps.
"
Class {
	#name : #SoBytecodeBuilder,
	#superclass : #SoGraphTraverser,
	#instVars : [
		'encoder',
		'referenceTranslator',
		'literals',
		'numTemps',
		'numArgs',
		'numCopied',
		'numStack',
		'basicBlocks',
		'deoptMapping',
		'blockOuterMapping',
		'extraTempIndex',
		'assignedTempIndexes'
	],
	#pools : [
		'SoSistaV1BytecodeSetConstants'
	],
	#category : #'Scorching-Backend-Bytecode'
}

{ #category : #accessing }
SoBytecodeBuilder >> assignedTempIndexes [
	<generated>
	^ assignedTempIndexes
]

{ #category : #accessing }
SoBytecodeBuilder >> assignedTempIndexes: aValue [
	<generated>
	assignedTempIndexes := aValue
]

{ #category : #jumps }
SoBytecodeBuilder >> backjumpSizeFrom: block1 to: block2 [
	^ self jumpSizeFrom: block2 postOrder to: block1 postOrder
]

{ #category : #accessing }
SoBytecodeBuilder >> basicBlocks [
	<generated>
	^ basicBlocks
]

{ #category : #accessing }
SoBytecodeBuilder >> basicBlocks: aValue [
	<generated>
	basicBlocks := aValue
]

{ #category : #results }
SoBytecodeBuilder >> basicGenBytecodes [
	| s |
	self fixJumps. " to compute correctly jump size"
	s := (ByteArray new: 100) writeStream.
	encoder stream: s.
	basicBlocks do: [ :bb |
		deoptMapping at: bb ifPresent: [ :map | self remap: map with: s position ].
		s nextPutAll: bb tempData.
		bb lastInstr isTraversedBy: self ].
	^ s contents
]

{ #category : #accessing }
SoBytecodeBuilder >> blockOuterMapping [
	<generated>
	^ blockOuterMapping
]

{ #category : #accessing }
SoBytecodeBuilder >> blockOuterMapping: aValue [
	<generated>
	blockOuterMapping := aValue
]

{ #category : #jumps }
SoBytecodeBuilder >> bytecodeSizeFor: jump [
	| distance |
	distance := self jumpDistance: jump.
	distance = 0 ifTrue: [ ^ jump popSize ].
	^ jump 
		bytecodeSizeFor: distance 
		bytecodeBuilder: self
]

{ #category : #jumps }
SoBytecodeBuilder >> collectJumps [
	^ basicBlocks inject: OrderedCollection new into: [ :acc :bb |
		| lastInstr |
		lastInstr := bb lastInstr.
		lastInstr isJump
			ifTrue: [ acc add: lastInstr ].
		acc ]
]

{ #category : #results }
SoBytecodeBuilder >> compiledCode: codeNode codeClass: codeClass [
	| cm bytes |
	self assert: codeClass == CompiledMethod. "Else installation not supported yet"
	basicBlocks := codeNode basicBlocks.
	bytes := self genBytecodes.
	self newMetadata: codeNode compiledCode.
	literals last debugInfo: codeNode debugInfo.
	cm := self newCompiledMethodFor: codeNode bytesSize: bytes size.
	self streamBytes: bytes toMethod: cm.
	self writeLiteralsToMethod: cm originalMethod: codeNode compiledCode.
	^ cm
]

{ #category : #jumps }
SoBytecodeBuilder >> computeTrueOrFalse: col [	
	"Annotate branch depending on if they are going to be generated as a jumpTrue or jumpFalse.
	The choice depends on the basicblocks order for code generation. Typically, all jumps are
	jumpFalse except if a jumpFalse would make a loop body non contiguous."
	col do: [ :jump |
		jump isBranch ifTrue: [
			jump backendCondition: (jump codeNode basicBlocks after: jump basicBlock) = jump trueBasicBlock ] ]
]

{ #category : #accessing }
SoBytecodeBuilder >> deoptMapping [
	<generated>
	^ deoptMapping
]

{ #category : #accessing }
SoBytecodeBuilder >> deoptMapping: aValue [
	<generated>
	deoptMapping := aValue
]

{ #category : #accessing }
SoBytecodeBuilder >> encoder [
	<generated>
	^ encoder
]

{ #category : #accessing }
SoBytecodeBuilder >> encoder: aValue [
	<generated>
	encoder := aValue
]

{ #category : #initialization }
SoBytecodeBuilder >> encoderClass [ 
	^ OpalEncoderForSistaV1
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> endBasicBlock: basicBlock [
	basicBlock tempData: encoder bytecodes.
	self newEncoderStream
]

{ #category : #accessing }
SoBytecodeBuilder >> extraTempIndex [
	<generated>
	^ extraTempIndex
]

{ #category : #accessing }
SoBytecodeBuilder >> extraTempIndex: aValue [
	<generated>
	extraTempIndex := aValue
]

{ #category : #jumps }
SoBytecodeBuilder >> fixJumps [
	| col |
	col := self collectJumps.
	self computeTrueOrFalse: col.
	self reduceJumps: col.
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genBasicSend: send [ 
	| litIndex argsSize |
	argsSize := send arguments size.
	litIndex := SpecialSelectors indexOf: send selector.
	litIndex > 0 
		ifTrue: [ encoder genSendSpecial: litIndex numArgs: argsSize ]
		ifFalse: [ litIndex := self literalIndexOf: send selector.
				  encoder genSend: litIndex numArgs: argsSize ]. 
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genBasicSuperSend: send [ 
	| index litIndex argsSize |
	argsSize := send arguments size.
	index := self literalIndexOf: send methodClass binding.
	encoder genPushLiteralVar: index.
	litIndex := self literalIndexOf: send selector.
	encoder genSendDirectedSuper: litIndex numArgs: argsSize 
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genBlockReturn [
	encoder genReturnTopToCaller 
]

{ #category : #results }
SoBytecodeBuilder >> genBytecodes [
	| bytes |
	bytes := self basicGenBytecodes.
	(self encoderClass isReturnByte: bytes last) ifFalse: 
		[ bytes := bytes , {self encoderClass returnSelfByte} ].
	^ bytes
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genCreateContextFullBlock: fullBlock [
	| recOnStack cb |
	"each one needs a different code to have a single identity to remap closure outercontext"
	cb := fullBlock compiledCode copy.
	recOnStack := fullBlock receiver isReceiver not.
	recOnStack ifTrue: [ referenceTranslator translate: fullBlock receiver ].
	referenceTranslator translateAll: fullBlock values.
	encoder 
		genPushFullClosure: (self literalIndexOf: cb) 
		numCopied: fullBlock values size 
		receiverOnStack: recOnStack
		outerContextNeeded: true.
	self mapOuter: cb to: fullBlock outerContextMarker
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genDeoptInfo: node [
	^ self recordDeoptPoint: (node deoptInfo asDeoptFor: node) basicBlock: node basicBlock
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genImmediateTrap: trap [
	encoder genTrap.
	self genDeoptInfo: trap.
	"encoder genPushReceiver.
	encoder genPop."
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genInstantiation: op [
	| index |
	index := self literalIndexOf: op behavior.
	encoder genPushLiteral: index.
	op subNodesDo: [ :sub | referenceTranslator translate: sub ].
	numStack := numStack max: op subNodesSize + 1.
	encoder genCallPrimitive: op primitiveNumber + (1<< 15)
	
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPop [ 
	encoder genPop
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPopIntoTemp: index [
	assignedTempIndexes add: index.
	encoder genStorePopTemp: (self tempIndex: index)
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPrimitive: primitive [

	primitive ifNil: [ ^ self ]. "no primitive"

	"named primitive"
	primitive literal ifNotNil: [ :lit | self literalIndexOf: lit ]. 
	
	"primitive number"
	encoder genCallPrimitive: primitive num.
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPushArg: arg [ 
	encoder genPushTemp: arg index
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPushConstant: cst [
	| index |
	(self encoderClass specialLiterals identityIncludes: cst constant) ifTrue: [ 
		^ encoder genPushSpecialLiteral: cst constant ].
	index := self literalIndexOf: cst constant.
	encoder genPushLiteral: index
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPushMutableLiteral: mutableLiteral [
	| index |
	index := self literalIndexOf: mutableLiteral literal.
	encoder genPushLiteral: index
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPushReceiver [
	encoder genPushReceiver
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genPushTemp: index [ 
	encoder genPushTemp: (self tempIndex: index)
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genReturn [
	encoder genReturnTop
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genReturnReceiver [
	encoder genReturnReceiver
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genReturnSpecialConstant: val [
	encoder genReturnSpecialLiteral: val constant
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genSend: send [
	"This code is complex mostly because of special selectors, which are important for performance"
	referenceTranslator translate: send receiver.
	referenceTranslator translateAll: send arguments.
	numStack := numStack max: send arguments size + 1.
	send methodClass 
		ifNotNil: [ self genBasicSuperSend: send ]
		ifNil: [ self genBasicSend: send  ].
	self genDeoptInfo: send
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> genUnsafeOp: op [
	op subNodesDo: [ :sub | referenceTranslator translate: sub ].
	numStack := numStack max: op subNodesSize.
	op isMapped 
		ifTrue: [ encoder genCallMappedInlinedPrimitive: op primitiveNumber.
				 op hasDeoptInfo ifTrue: [ self genDeoptInfo: op ] ]
		ifFalse: [ encoder genCallPrimitive: op primitiveNumber + (1<< 15) ]
	
]

{ #category : #testing }
SoBytecodeBuilder >> hasBeenAssigned: index [
	^ assignedTempIndexes includes: index
]

{ #category : #initialization }
SoBytecodeBuilder >> initialize [

	super initialize.

	encoder := self encoderClass new.
	self newEncoderStream.
	literals := OrderedCollection new.
	numArgs := 0.
	numCopied := 0.
	numTemps := 0.
	numStack := 1. "to simplify.."
	deoptMapping := Dictionary new.
	assignedTempIndexes := Set new.
]

{ #category : #initialization }
SoBytecodeBuilder >> initializeWith: codeNode [
	self numArgs: codeNode numArgs.
	self genPrimitive: codeNode primitive.
	extraTempIndex := codeNode backendMaxTempIndex + 1.
]

{ #category : #jumps }
SoBytecodeBuilder >> jumpDistance: jump [
	^ jump isBackjump
				ifFalse: [ self jumpForwardSizeFrom: jump basicBlock to: jump targetBasicBlock ]
				ifTrue: [ self backjumpSizeFrom: jump basicBlock to: jump targetBasicBlock ]
]

{ #category : #jumps }
SoBytecodeBuilder >> jumpForwardSizeFrom: block1 to: block2 [
	^ self jumpSizeFrom: block1 postOrder + 1 to: block2 postOrder - 1
]

{ #category : #jumps }
SoBytecodeBuilder >> jumpSizeFrom: index1 to: index2 [
	| distance bb |
	distance := 0.
	index1 to: index2 do: [ :i |
		bb := basicBlocks at: i.
		distance := distance + bb tempData size + bb lastInstr backEndJumpSize ].
	^ distance
]

{ #category : #accessing }
SoBytecodeBuilder >> literalIndexOf: lit [
	^ (literals 
		identityIndexOf: lit 
		ifAbsent: [ literals addLast: lit. literals size ]) - 1
]

{ #category : #accessing }
SoBytecodeBuilder >> literals [
	<generated>
	^ literals
]

{ #category : #accessing }
SoBytecodeBuilder >> literals: aValue [
	<generated>
	literals := aValue
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> mapOuter: compiledBlock to: ctxtMarker [
	blockOuterMapping ifNil: [ blockOuterMapping := SoDeoptDictionary new ].
	blockOuterMapping at: compiledBlock put: ctxtMarker
]

{ #category : #results }
SoBytecodeBuilder >> newCompiledMethodFor: codeNode bytesSize:  size [
	^ codeNode compiledCode trailer 
		createMethod: size 
		class: CompiledMethod 
		header: (self spurHeaderFor: codeNode bytesSize: size)
]

{ #category : #initialization }
SoBytecodeBuilder >> newEncoderStream [
	encoder stream: (ByteArray new: 50) writeStream
]

{ #category : #results }
SoBytecodeBuilder >> newMetadata: method [
	| metadata |
	metadata := SoDeoptMetadata new 
		unoptimizedMethod: method; 
		yourself.
	deoptMapping valuesDo: [ :bbEntries |
		bbEntries do: [ :assoc |
			metadata deoptPoints at: assoc key put: (SoDeoptArray from: assoc value) ] ].
	metadata blockOuters: blockOuterMapping.
	literals addLast: metadata.
	
]

{ #category : #accessing }
SoBytecodeBuilder >> numArgs [
	<generated>
	^ numArgs
]

{ #category : #accessing }
SoBytecodeBuilder >> numArgs: aValue [
	<generated>
	numArgs := aValue
]

{ #category : #accessing }
SoBytecodeBuilder >> numCopied [
	<generated>
	^ numCopied
]

{ #category : #accessing }
SoBytecodeBuilder >> numCopied: aValue [
	<generated>
	numCopied := aValue
]

{ #category : #accessing }
SoBytecodeBuilder >> numStack [
	<generated>
	^ numStack
]

{ #category : #accessing }
SoBytecodeBuilder >> numStack: aValue [
	<generated>
	numStack := aValue
]

{ #category : #accessing }
SoBytecodeBuilder >> numTemps [
	<generated>
	^ numTemps
]

{ #category : #accessing }
SoBytecodeBuilder >> numTemps: aValue [
	<generated>
	numTemps := aValue
]

{ #category : #'bytecode generation' }
SoBytecodeBuilder >> recordDeoptPoint: deoptPoint basicBlock: basicBlock [
	| pc |
	pc := encoder methodStreamPosition + 1.
	deoptMapping 
		at: basicBlock 
		ifPresent: [ :col | col add: pc -> deoptPoint ]
		ifAbsentPut: [ OrderedCollection with: pc -> deoptPoint ] 
]

{ #category : #jumps }
SoBytecodeBuilder >> reduceJumpSize: col [
	"computes the number of bytes used for each jump. Starts with only long jumps. 
	Reduces the jump encoding size as much as possible."
	| change |
	change := true.
	[ change ] whileTrue:
		[ change := false.
		col do: [ :jump |
			| newSize |
			newSize := self bytecodeSizeFor: jump.
			jump backEndJumpSize = newSize ifFalse: [  
				change := true.
				jump backEndJumpSize: newSize ] ] ]
]

{ #category : #jumps }
SoBytecodeBuilder >> reduceJumps: col [	
	self setDefaultJumpSizes: 7 for: col.
	self reduceJumpSize: col
]

{ #category : #accessing }
SoBytecodeBuilder >> referenceTranslator [
	<generated>
	^ referenceTranslator
]

{ #category : #accessing }
SoBytecodeBuilder >> referenceTranslator: aValue [
	<generated>
	referenceTranslator := aValue
]

{ #category : #results }
SoBytecodeBuilder >> remap: map with: position [
	map do: [ :assoc |
		assoc key: assoc key + position ]
]

{ #category : #jumps }
SoBytecodeBuilder >> setDefaultJumpSizes: int for: col [
	col do: [ :jump |
		jump backEndJumpSize: int ]
]

{ #category : #results }
SoBytecodeBuilder >> spurHeaderFor: codeNode bytesSize: size [
	| flag |
	flag := (Smalltalk version includesSubString: 'Squeak')
		ifTrue: [ self encoderClass new ]
		ifFalse: [ self encoderClass ].
	numTemps + numStack  > CompiledMethod fullFrameSize ifTrue: [ 
		^ self error: 'Cannot generate code -- stack including temps is too deep' ].
	^ (CompiledMethod headerFlagForEncoder: flag) +
		(numArgs bitShift: 24) +
		(numTemps + numArgs bitShift: 18) +
		(((numTemps + numStack > CompiledMethod smallFrameSize) asBit) bitShift: 17) + 
		literals size + 2 +
		(1 << 15) + "mark optimized method"
		(codeNode primitive notNil asBit bitShift: 16).
]

{ #category : #results }
SoBytecodeBuilder >> streamBytes: bytes toMethod: method [
	| stream |
	stream := WriteStream with: method.
	stream
		position: method initialPC - 1;
		nextPutAll: bytes
]

{ #category : #accessing }
SoBytecodeBuilder >> tempIndex: index [
	numTemps := numTemps max: index.
	^ index + numArgs + numCopied - 1
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseBranch: branch [
	| distance next |
	distance := self jumpForwardSizeFrom: branch basicBlock to: branch targetBasicBlock.
	(distance = 0 and: [ branch backEndJumpSize = 1 ]) ifTrue: [ ^ encoder genPop ].
	next := branch codeNode basicBlocks at: (branch codeNode basicBlocks indexOf: branch basicBlock) + 1.
	self 
		assert: (branch trueBasicBlock = next or: [branch falseBasicBlock = next])
		description: 'branch incorrect'.
	encoder genPushIntegerLong: distance.
	branch backendCondition
		ifTrue: [ encoder genCallInlinePrimitive: branch primitiveNumber ]
		ifFalse: [ encoder genCallInlinePrimitive: branch invertedPrimitiveNumber ]
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseImmediateTrap: trap [
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseInstanceOfBranch: branch [
	| distance next |
	distance := self jumpForwardSizeFrom: branch basicBlock to: branch targetBasicBlock.
	(distance = 0 and: [ branch backEndJumpSize = 2 ]) ifTrue: [ encoder genPop. ^ encoder genPop ].
	next := branch codeNode basicBlocks at: (branch codeNode basicBlocks indexOf: branch basicBlock) + 1.
	self 
		assert: (branch trueBasicBlock = next or: [branch falseBasicBlock = next])
		description: 'branch incorrect'.
	encoder genPushIntegerLong: distance.
	branch backendCondition
		ifTrue: [ encoder genCallInlinePrimitive: branch primitiveNumber ]
		ifFalse: [ encoder genCallInlinePrimitive: branch invertedPrimitiveNumber ]
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseJumpAhead: jumpAhead [ 
	jumpAhead backEndJumpSize = 0 ifTrue: [ ^ self "no jump" ].
	encoder genJump: (self jumpForwardSizeFrom: jumpAhead basicBlock to: jumpAhead targetBasicBlock)
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseNoInterruptBackjump: backjump [
	encoder genPushIntegerLong: (self backjumpSizeFrom: backjump basicBlock to: backjump targetBasicBlock) negated.
	encoder genCallPrimitive: (1 << 15) +  6000.
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traversePipelinedBooleanBranch: branch [
	| distance next |
	distance := self jumpForwardSizeFrom: branch basicBlock to: branch targetBasicBlock.
	next := branch codeNode basicBlocks at: (branch codeNode basicBlocks indexOf: branch basicBlock) + 1.
	self 
		assert: (branch trueBasicBlock = next or: [branch falseBasicBlock = next])
		description: 'Boolean branch incorrect'.
	(distance = 0 and: [ branch backEndJumpSize = 1 ]) ifTrue: [ ^ encoder genPop ].
	branch backendCondition
			ifTrue: [ encoder genBranchPopFalse: distance ]
			ifFalse: [ encoder genBranchPopTrue: distance ].
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseReturn: ret [
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseSmalltalkBackjump: backjump [
	self genDeoptInfo: backjump.
	encoder genJump: (self backjumpSizeFrom: backjump basicBlock to: backjump targetBasicBlock) negated.
]

{ #category : #'jump - generation' }
SoBytecodeBuilder >> traverseSmalltalkBooleanBranch: branch [
	self traversePipelinedBooleanBranch: branch.
	self genDeoptInfo: branch 
]

{ #category : #results }
SoBytecodeBuilder >> writeLiteralsToMethod: cm originalMethod: method [
	literals withIndexDo: [ :lit :i | cm literalAt: i put: lit ].
	cm selector: method selector.
	cm methodClass: method methodClass.
]
