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

		Node*[capacityBranches] _branches;
	}

@safe pure nothrow:

	this(Node* parent, Leaf[] leaves) {
		_parent = parent;
		_leaves[0 .. leaves.length] = leaves[];
		_length = leaves.length;
	}

	bool isRoot() const @nogc {
		return (_parent is null);
	}

	bool isFull() const @nogc {
		return (_length == capacityLeaves);
	}

	bool hasBranches() const @nogc {
		return (_branches.length > 0);
	}

	Leaf[] leaves() @nogc {
		return _leaves[0 .. _length];
	}

	Node*[] branches() @nogc {
		return _branches[0 .. _length + 1];
	}

	void spliceInsert(size_t offset, Leaf add) @nogc {
		foreach_reverse (idx, leaf; _leaves[offset .. _length]) {
			_leaves[offset + idx + 1] = leaf;
		}

		_leaves[offset] = add;
		++_length;
	}

	void endInsert(Leaf add) @nogc {
		_leaves[_length] = add;
		++_length;
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

	bool insert(Leaf add) {
		if (_length == 0) {
			assert(this.isRoot);
			return this.selfInsert(add);
		}

		if (this.isFull) {
			if (!this.hasBranches) {
			}
		}

		if (_length < capacityLeaves) {
			return this.selfInsert(add);
		}

		// TODO
		assert(false, "not implemented");
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
	void insert(Key key, Value value) {
		auto leaf = Leaf(key, value);

		if (_root is null) {
			_root = new Node(null, null);
		}

		_root.insert(leaf);
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
