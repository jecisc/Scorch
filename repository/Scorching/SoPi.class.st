"
Implements the pi function of e-SSA form.

The pi function is a replica of the node it refers, but it has a different range information.
"
Class {
	#name : #SoPi,
	#superclass : #SoAbsBodyInstruction,
	#instVars : [
		'expression',
		'additionalRange'
	],
	#category : #'Scorching-Nodes-Body Instructions'
}

{ #category : #accessing }
SoPi >> additionalRange [
	<generated>
	^ additionalRange
]

{ #category : #accessing }
SoPi >> additionalRange: aValue [
	<generated>
	additionalRange := aValue
]

{ #category : #'graph edition' }
SoPi >> basicReplaceSubNode: node by: anotherNode [
	<generated>
	expression := anotherNode.
	anotherNode addUse: self
]

{ #category : #types }
SoPi >> basicTypeInformation [
	^ SoType smi
]

{ #category : #accessing }
SoPi >> expression [
	<generated>
	^ expression
]

{ #category : #accessing }
SoPi >> expression: aValue [
	<generated>
	expression := aValue.
	expression  addUse: self
]

{ #category : #testing }
SoPi >> hasRangeInformation [
	^ true
]

{ #category : #testing }
SoPi >> isIteratorMutator: phi [
	^ true
]

{ #category : #testing }
SoPi >> isPi [
	^ true
]

{ #category : #traversing }
SoPi >> isTraversedBy: aTraverser [
	<generated>
	^ aTraverser traversePi: self
]

{ #category : #accessing }
SoPi >> iteratorMutatorValue: phi [
	^ 0
]

{ #category : #types }
SoPi >> nextIterator: phi [
	^ expression
]

{ #category : #types }
SoPi >> rangeInformation [
	^ expression hasRangeInformation 
		ifFalse: [ additionalRange ]
		ifTrue: [ expression rangeInformation intersection: additionalRange ]
]

{ #category : #'graph edition' }
SoPi >> subNodes [
	<generated>
	^ {expression}
]

{ #category : #'graph edition' }
SoPi >> subNodesAnySatisfy: aBlock [
	"profiling"
	<generated>
	^aBlock value: expression.
	
]

{ #category : #'graph edition' }
SoPi >> subNodesDo: aBlock [
	"profiling"
	<generated>
	aBlock value: expression
]

{ #category : #'graph edition' }
SoPi >> subNodesSize [
	<generated>
	^ 1
]
