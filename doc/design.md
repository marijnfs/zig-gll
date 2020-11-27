ZIG GLL
=======
General GLL (general LL) parser in Zig

Enums:
=====
#RuleType
- Option
- Match
- Return
- End

Internal Structs:
================
#NodeIndex
- cursor: int
- rule: int
- id: int
- prev: int
> cmp(other: NodeIndex) bool

Nodeindex is unique for a given cursor+rule. This gives us the cap on memory usage and efficiency (dynamic algorithm).
Has a comparator to distinguish if a new node needs to be created or just adjusted


Structs:
=======
#RuleSet
- names: []string
- types: []RuleType
- arguments [nargs][]int      #inputs for Option types
- matcher: []?RE2Matcher      #matchers for Match types

                              !Not used in Code?#
- returns: []int              #begin rule for End types


#Parser
- ruleset: Ruleset
- heads: priority_queue(NodeIndex)  #Main active queue for parsing

- nodes: NodeIndex
- properties: int             #index pointing to node with info
- parents: []set(int)         #Spawning node for this rule
- prevs: []int                #pointing to previous rule in a sequence

- node_occurence: set(NodeIndex) #faster data structure to check if node exists already

- crumbs: []set(int)          #Used in reading out the parse graph
- end_node: int               #Index of end node, for deparsing
- furthest: int               #Cursor of furthest parsing node, for giving errors

+ Provides query operations like:
  + get_all(type) for one node, or recursively
  + squeeze, for recursive nodes that we would want in sequence (like having all lines in a block under one node)
  + cleanup, remove nodes of certain types and compact them
  + visitor, visit functionality, bottom up and top down, pass through or not
+ Has pretty printing functionality

Result Structs:
==============

#ParseNode              #Represents Parse Tree
- n: int                #index, -1 is invalid default state
- parents: []int        #parents
- children: []int       #children

#ParseGraph             #Main Parse result representation
- nodes: []ParseNode
- starts: []int         #Start cursor position of this element
- ends: []int           #End cursor position of this element
- type_ids: []int       #Rule ID (not RuleType!) of this node
- buffer: []u8          #Contains actual string buffer of what is parsed

   #Aux variables, possibly should be externalized
- cleanup: []bool       #variable used in execution of function
- type_map: [int]string           #Rule ID to name map
- reverse_type_map: [string]int   #Reverse of above

Parsing Logic:
=============
Remind the 4 types of RuleType: Option, Match, Return, End.
End marks the end of any parse. The goal is to make End fall on the final cursor _len(buffer)_

Match
-----
The essential text matcher. We use RE2 for it's simple definitions (like regex but not as stupid). Can match things like a number, a set of numbers, alphanumerics, specific strings, and more complex aggregate types. Several rules can also be used in sequence, as we simply start matching the next rule.

Examples:
'\*' #match the * symbol. Needs to be escaped as "+-()\*" have special meanings in RE2
'\n' matches end of line (screw windows, or add if you care)
```
'[[:digit:]]+' defines one or more digits
'[_[:alpha:]]+' defines multiple alpha numbers and underscore in a set
"[^\']*" Defines stuff that is __not__ a quote
```

Option
------
An Option spawns several possible other nodes. E.g. perhaps a _line_ can be a _statement/assignment/block_. You use an Option to define these possibilities

Defined with an | Symbol

Return
------
Marks the end of a sequence of rules, time to return to whoever spawned it.
Just like a function call.

End
---
Marks the end of the Parse. Could perhaps also be done with Return, but it's convenient to be explicit about it.


Bootstrap:
=========
- We have a simple default parse that reads a restricted grammar rule
- This parses definition of the syntax in which grammar rules are defined
- The resulting Parser is the basis of the __actual__ parser

PostProcessing:
==============
- Several processes to improve the graph / Read graph
- Can either create callback on types (bottom up / top down)
- Can mark items for removal (bottom up / top down)
- Can decide to pass through items, or stop searching further


Discussion
==========
# Why is RuleSet type not the same as types in ParseGraph?
- There are Root types explicitly added not in Ruleset
  - Could be added
- There are unnamed types
  - No problem
- Multiple RuleSets active?
  - This becomes a problem indeed
  - But string type name also isn't unique anymore probably
  - Better define RuleSets in use in the beginning, and determine all possible types
>> Should probably use type of ruleset, or an aggregated type

