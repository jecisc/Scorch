"
I represent information to know how to generate the instructions into a stack based representation (expression tree reconstruction).

These annotations are generated by the SpillAnalysis pass.
"
Class {
	#name : #SoSpillState,
	#superclass : #SoGraphTraverser,
	#category : #'Scorching-Backend-Bytecode'
}

{ #category : #testing }
SoSpillState >> isSpilled [
	^ false
]

{ #category : #testing }
SoSpillState >> isTemp [
	^ false
]
