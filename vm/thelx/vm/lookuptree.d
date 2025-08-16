module thelx.vm.lookuptree;

import std.traits : isArray;

struct LookupResult(Value) {
	bool found;
	Value value;
}

private struct LookupTreeLeaf(Key, Value) {

	private {
		alias Leaf = typeof(this);
	}

	public {
		Key key;
		Value value;
	}

@safe pure nothrow @nogc:

	bool hasIdenticalKeyTo(const Leaf other) const {
		return (this.key == other.key);
	}

	int opCmp(const Leaf other) const {
		static if (isArray!Key) {
			foreach (idx, a; this.key) {
				if (idx == other.key.length) {
					return 1;
				}

				const b = other.key[idx];
				if (a == b) {
					continue;
				}

				return ((a > b) - (a < b));
			}

			return (this.key.length < other.key.length) ? -1 : 0;
		}
		else {
			return ((this.key > other.key) - (this.key < other.key));
		}
	}
}

private enum splitIdxOf(size_t length) = ((length >> 1) + (length % 2));

private struct LookupTreeNode(Key, Value, size_t capacityLeaves) {

	private {
		alias Leaf = LookupTreeLeaf!(Key, Value);
		alias Node = typeof(this);

		enum capacityBranches = (capacityLeaves + 1);
		enum minLength = (capacityLeaves >> 1);
	}

	private {
		Node* _parent;

		Leaf[capacityLeaves] _leaves;
		size_t _length = 0;
		bool _hasBranches = false;

		Node*[capacityBranches] _branches;
	}

@safe pure nothrow:

	this(Node* parent, Leaf leaf) @nogc {
		_parent = parent;
		_leaves[0] = leaf;
		_length = 1;
	}

	this(Node* parent, scope Leaf[] leaves) @nogc {
		_parent = parent;
		_leaves[0 .. leaves.length] = leaves[];
		_length = leaves.length;
	}

	this(Node* parent, scope Leaf[] leaves, scope Node*[] branches) @nogc {
		this(parent, leaves);

		_branches[0 .. branches.length] = branches[];
		_hasBranches = true;

		assert(branches.length == branchesCount);
	}

	this(Node* parent, scope Leaf[] leaves, Node* firstBranch, scope Node*[] furtherBranches) @nogc {
		this(parent, leaves);

		assert((1 + furtherBranches.length) <= _branches.length);

		_branches[0] = firstBranch;
		_branches[1 .. 1 + furtherBranches.length] = furtherBranches[];
		_hasBranches = true;

		assert((1 + furtherBranches.length) == branchesCount);
	}

	private Node* getPointer() @trusted pure nothrow {
		import core.memory : GC;

		auto ptr = &this;
		if (GC.addrOf(ptr) is null) {
			assert(false);
		}

		return ptr;
	}

	bool isRoot() const @nogc {
		return (_parent is null);
	}

	bool isFull() const @nogc {
		return (_length == capacityLeaves);
	}

	bool hasBranches() const @nogc {
		return _hasBranches;
	}

	size_t leavesCount() const @nogc {
		return _length;
	}

	size_t branchesCount() const @nogc {
		return (_hasBranches) ? _length + 1 : 0;
	}

	Leaf[] leaves() @nogc {
		return _leaves[0 .. _length];
	}

	Node*[] branches() @nogc {
		return _branches[0 .. branchesCount];
	}

	Node* findBranch(Key key) {
		assert(_hasBranches);

		foreach (idx, leaf; leaves) {
			if (key < leaf.key) {
				return _branches[idx];
			}
		}

		return _branches[branchesCount - 1];
	}

	void spliceInsert(size_t offset, Leaf add) @nogc {
		foreach_reverse (idx, leaf; _leaves[offset .. _length]) {
			_leaves[offset + idx + 1] = leaf;
		}

		_leaves[offset] = add;
		++_length;
	}

	void spliceInsert(size_t offset, Node* add) @nogc {
		const count = branchesCount - 1;
		foreach_reverse (idx, branch; _branches[offset .. count]) {
			_branches[offset + idx + 1] = branch;
		}

		_branches[offset] = add;
	}

	void endInsert(Leaf add) @nogc {
		_leaves[_length] = add;
		++_length;
	}

	void endInsert(Leaf add, Node* greater) @nogc {
		_leaves[_length] = add;
		++_length;
		_branches[_length] = greater;
	}

	bool selfInsert(Leaf add) @nogc {
		assert(!this.isFull);

		foreach (idx, leaf; leaves) {
			if (add.hasIdenticalKeyTo(leaf)) {
				return false;
			}

			if (add < leaf) {
				this.spliceInsert(idx, add);
				return true;
			}
		}

		this.endInsert(add);
		return true;
	}

	void selfInsertSplit(Leaf add, Node* toSplit) {
		assert(!this.isFull);

		size_t idxInsertLeaf = leavesCount;
		foreach (idx, leaf; leaves) {
			if (add < leaf) {
				idxInsertLeaf = idx;
				break;
			}
		}
		this.spliceInsert(idxInsertLeaf, add);

		foreach (idx, branch; branches) {
			if (branch is toSplit) {
				assert(idx == idxInsertLeaf);

				auto less = toSplit.splitDropLower(this.getPointer());
				this.spliceInsert(idx, less);
				return;
			}
		}

		assert(false, "Cannot split unrelated branch.");
	}

	Node* splitDropLower(Node* parent) {
		enum idxSplit = splitIdxOf!capacityLeaves;
		auto lower = new Node(parent, _leaves[0 .. idxSplit]);
		auto upper = _leaves[idxSplit .. $];
		_leaves[0 .. upper.length] = upper;
		_leaves[upper.length .. $] = null;
		_length = upper.length;
		return lower;
	}

	Node* splitCopyLower(Node* parent) {
		enum idxSplit = splitIdxOf!capacityLeaves;
		enum idxSplitBranches = idxSplit + 1;
		// dfmt off
		return (hasBranches)
			? new Node(parent, _leaves[0 .. idxSplit], _branches[0 .. idxSplitBranches])
			: new Node(parent, _leaves[0 .. idxSplit]);
		// dfmt on
	}

	Node* splitCopyUpper(Node* parent) {
		assert(!hasBranches);

		enum idxSplit = splitIdxOf!capacityLeaves;
		return new Node(parent, _leaves[idxSplit .. $]);
	}

	Node* splitCopyUpper(Node* parent, Node* lessThanUpper) {
		assert(hasBranches);

		enum idxSplit = splitIdxOf!capacityLeaves;
		enum idxSplitBranches = idxSplit + 1;
		return new Node(
			parent,
			_leaves[idxSplit .. $],
			lessThanUpper,
			_branches[idxSplitBranches .. $],
		);
	}

	void push(Leaf anchor, Node* toSplit) {
		if (isFull) {
			Leaf parentAnchor;
			const shuffled = this.shuffle(anchor, parentAnchor);
			assert(shuffled);

			Node* lessThanUpper;
			this.shuffle(toSplit, lessThanUpper);

			this.pushToParent(parentAnchor, lessThanUpper);
			return;
		}

		this.selfInsertSplit(anchor, toSplit);
	}

	void promoteToParent(Leaf anchor, Node* lessThanUpper = null) {
		assert(isFull);

		// dfmt off
		Node* less = this.splitCopyLower(this.getPointer());
		Node* greater = (lessThanUpper is null)
			? this.splitCopyUpper(this.getPointer())
			: this.splitCopyUpper(this.getPointer(), lessThanUpper);
		// dfmt on

		_leaves[0] = anchor;
		_leaves[1 .. $] = null;
		_length = 1;

		_branches[0] = less;
		_branches[1] = greater;
		_branches[2 .. $] = null;
		_hasBranches = true;
	}

	void pushToParent(Leaf anchor) {
		if (_parent is null) {
			promoteToParent(anchor);
			return;
		}

		_parent.push(anchor, this.getPointer());
	}

	void pushToParent(Leaf anchor, Node* lessThanUpper) {
		if (_parent is null) {
			promoteToParent(anchor, lessThanUpper);
			return;
		}

		// TODO
		assert(false);
		//_parent.push(anchor, this.getPointer());
	}

	bool shuffle(Leaf add, out Leaf anchor) @nogc {
		assert(isFull);
		Leaf[capacityLeaves + 1] buffer;

		size_t copyOffset = 0;
		foreach (idx, leaf; leaves) {
			if ((copyOffset == 0) && (add < leaf)) {
				copyOffset = 1;
				buffer[idx] = add;
			}

			if (add.hasIdenticalKeyTo(leaf)) {
				return false;
			}

			buffer[idx + copyOffset] = leaf;
		}

		if (copyOffset == 0) {
			enum idxFinal = -1 + buffer.length;
			buffer[idxFinal] = add;
		}

		enum idxAnchor = (buffer.length >> 1) + 1 - (buffer.length % 2);
		enum idxSplit = splitIdxOf!capacityLeaves;

		anchor = buffer[idxAnchor];
		_leaves[0 .. idxSplit] = buffer[0 .. idxAnchor];
		_leaves[idxSplit .. $] = buffer[idxAnchor + 1 .. $];

		return true;
	}

	void shuffle(Node* toSplit, out Node* lessThanUpper) {
		assert(isFull);
		Node*[capacityBranches + 1] buffer;

		size_t copyOffset = 0;
		foreach (idx, branch; branches) {
			if (branch is toSplit) {
				copyOffset = 1;
				buffer[idx] = branch.splitDropLower(_parent);
			}

			buffer[idx + copyOffset] = branch;
		}

		assert(copyOffset == 1);

		enum idxLessThanUpper = (buffer.length >> 1) + (buffer.length % 2);
		enum idxSplit = splitIdxOf!capacityLeaves;
		enum idxSplitBranches = idxSplit + 1;

		lessThanUpper = buffer[idxLessThanUpper];
		_branches[0 .. idxSplitBranches] = buffer[0 .. idxLessThanUpper];
		_branches[idxSplitBranches .. $] = buffer[idxLessThanUpper + 1 .. $];
	}

	bool splitInsert(Leaf add) {
		assert(leaves.length == capacityLeaves);

		Leaf anchor;
		const shuffled = this.shuffle(add, anchor);
		if (!shuffled) {
			return false;
		}

		this.pushToParent(anchor);
		return true;
	}

	bool insert(Leaf add) {
		if (_length == 0) {
			assert(this.isRoot);
			this.endInsert(add);
			return true;
		}

		if (hasBranches) {
			return this.findBranch(add.key).insert(add);
		}

		if (isFull) {
			return this.splitInsert(add);
		}

		return this.selfInsert(add);
	}
}

///
struct LookupTree(Key, Value, size_t capacityLeaves = 4) {

	static assert(capacityLeaves >= 1, "`capacityLeaves` must be >= 1.");

	private {
		alias Leaf = LookupTreeLeaf!(Key, Value);
		alias Node = LookupTreeNode!(Key, Value, capacityLeaves);
		alias Tree = typeof(this);
	}

	private {
		Node* _root = null;
	}

@safe pure nothrow:

	///
	bool insert(Key key, Value value) {
		auto leaf = Leaf(key, value);

		if (_root is null) {
			_root = new Node(null, null);
		}

		return _root.insert(leaf);
	}
}

@safe pure nothrow @nogc unittest {
	alias Leaf = LookupTreeLeaf!(int, typeof(null));
	assert(Leaf(1) < Leaf(2));
	assert(Leaf(2) > Leaf(1));
	assert(Leaf(1) == Leaf(1));
}

@safe pure nothrow @nogc unittest {
	alias Leaf = LookupTreeLeaf!(string, typeof(null));

	assert(Leaf("a") < Leaf("b"));
	assert(Leaf("b") > Leaf("a"));
	assert(Leaf("a") == Leaf("a"));

	assert(Leaf("a") < Leaf("aa"));
	assert(Leaf("az") > Leaf("a"));

	assert(Leaf("ab") < Leaf("az"));
}

@safe pure nothrow unittest {
	alias Node = LookupTreeNode!(int, typeof(null), 4);
	alias Leaf = Node.Leaf;

	{
		auto node = Node(null, [
			Leaf(1),
			Leaf(3),
			Leaf(4),
		]);

		node.spliceInsert(1, Leaf(2));
		assert(node.leaves == [
			Leaf(1),
			Leaf(2),
			Leaf(3),
			Leaf(4),
		]);
	}

	{
		auto node = Node(null, [
			Leaf(1),
			Leaf(2),
			Leaf(4),
		]);

		node.spliceInsert(2, Leaf(3));
		assert(node.leaves == [
			Leaf(1),
			Leaf(2),
			Leaf(3),
			Leaf(4),
		]);
	}

	{
		auto node = Node(null, [
			Leaf(1),
			Leaf(3),
			Leaf(4),
		]);

		node.selfInsert(Leaf(2));
		assert(node.leaves == [
			Leaf(1),
			Leaf(2),
			Leaf(3),
			Leaf(4),
		]);
	}

	{
		auto node = Node(null, [
			Leaf(1),
			Leaf(2),
			Leaf(4),
		]);

		node.selfInsert(Leaf(3));
		assert(node.leaves == [
			Leaf(1),
			Leaf(2),
			Leaf(3),
			Leaf(4),
		]);
	}

	{
		auto node = Node(null, []);

		node.selfInsert(Leaf(1));
		assert(node.leaves == [
			Leaf(1),
		]);

		node.selfInsert(Leaf(4));
		assert(node.leaves == [
			Leaf(1),
			Leaf(4),
		]);

		node.selfInsert(Leaf(3));
		assert(node.leaves == [
			Leaf(1),
			Leaf(3),
			Leaf(4),
		]);

		node.selfInsert(Leaf(2));
		assert(node.leaves == [
			Leaf(1),
			Leaf(2),
			Leaf(3),
			Leaf(4),
		]);
	}
}

@safe pure nothrow unittest {
	alias Tree = LookupTree!(int, typeof(null), 4);
	alias Leaf = Tree.Leaf;

	auto tree = Tree();
	tree.insert(4, null);
	tree.insert(1, null);

	assert(tree._root.leaves == [
		Leaf(1),
		Leaf(4),
	]);
}

@safe pure nothrow unittest {
	alias Tree = LookupTree!(int, typeof(null), 4);
	alias Leaf = Tree.Leaf;

	auto tree = Tree();
	assert(tree.insert(20, null));
	assert(tree.insert(40, null));
	assert(tree.insert(30, null));
	assert(tree.insert(10, null));
	assert(tree._root.leaves == [
		Leaf(10),
		Leaf(20),
		Leaf(30),
		Leaf(40),
	]);

	assert(tree.insert(25, null));
	assert(tree._root.leaves == [
		Leaf(25),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(20),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(30),
		Leaf(40),
	]);

	assert(tree.insert(21, null));
	assert(tree.insert(22, null));
	assert(tree._root.leaves == [
		Leaf(25),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(20),
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(30),
		Leaf(40),
	]);

	assert(tree.insert(26, null));
	assert(tree.insert(32, null));
	assert(tree._root.leaves == [
		Leaf(25),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(20),
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(26),
		Leaf(30),
		Leaf(32),
		Leaf(40),
	]);

	assert(tree.insert(11, null));
	assert(tree._root.leaves == [
		Leaf(20),
		Leaf(25),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(11),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[2].leaves == [
		Leaf(26),
		Leaf(30),
		Leaf(32),
		Leaf(40),
	]);

	assert(tree.insert(41, null));
	assert(tree._root.leaves == [
		Leaf(20),
		Leaf(25),
		Leaf(32),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(11),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[2].leaves == [
		Leaf(26),
		Leaf(30),
	]);
	assert(tree._root.branches[3].leaves == [
		Leaf(40),
		Leaf(41),
	]);

	assert(tree.insert(31, null));
	assert(tree.insert(28, null));
	assert(tree._root.branches[2].leaves == [
		Leaf(26),
		Leaf(28),
		Leaf(30),
		Leaf(31),
	]);

	assert(tree.insert(29, null));
	assert(tree._root.leaves == [
		Leaf(20),
		Leaf(25),
		Leaf(29),
		Leaf(32),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(11),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[2].leaves == [
		Leaf(26),
		Leaf(28),
	]);
	assert(tree._root.branches[3].leaves == [
		Leaf(30),
		Leaf(31),
	]);
	assert(tree._root.branches[4].leaves == [
		Leaf(40),
		Leaf(41),
	]);

	assert(tree.insert(12, null));
	assert(tree.insert(14, null));
	assert(tree._root.branches[0].leaves == [
		Leaf(10),
		Leaf(11),
		Leaf(12),
		Leaf(14),
	]);

	assert(tree.insert(13, null));
	assert(tree._root.leaves == [
		Leaf(25),
	]);
	assert(tree._root.branches[0].leaves == [
		Leaf(12),
		Leaf(20),
	]);
	assert(tree._root.branches[1].leaves == [
		Leaf(29),
		Leaf(32),
	]);
	assert(tree._root.branches[0].branches[0].leaves == [
		Leaf(10),
		Leaf(11),
	]);
	assert(tree._root.branches[0].branches[1].leaves == [
		Leaf(13),
		Leaf(14),
	]);
	assert(tree._root.branches[0].branches[2].leaves == [
		Leaf(21),
		Leaf(22),
	]);
	assert(tree._root.branches[1].branches[0].leaves == [
		Leaf(26),
		Leaf(28),
	]);
	assert(tree._root.branches[1].branches[1].leaves == [
		Leaf(30),
		Leaf(31),
	]);
	assert(tree._root.branches[1].branches[2].leaves == [
		Leaf(40),
		Leaf(41),
	]);
}
