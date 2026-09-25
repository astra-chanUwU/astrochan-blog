---
title: "Binary Trees, Binary Tries, and Interview Questions Worth Asking"
description: "Invert a tree, build a binary trie, and turn familiar interview puzzles into useful conversations about how we reason."
date: 2026-09-25
slug: "binary-trees-and-binary-tries"
toc: true
tags: [algorithms, javascript, interviews]
---

I knew what a binary tree was. I learned the idea at university, then later ran
into **binary tries** and thought: wait, a binary *what* now?

That happens in programming. You can understand the underlying idea and still
meet a data structure, operator, or runtime detail that makes you feel like
everyone else got a memo you missed. I find it more useful to build the thing
and poke at it than to memorize another definition.

Let's start with a familiar interview question: invert a binary tree.

## Invert a binary tree

Given this tree:

```text
        4
       / \
      2   7
     / \ / \
    1  3 6  9
```

we want this:

```text
        4
       / \
      7   2
     / \ / \
    9  6 3  1
```

At every node, swap its left and right children. Then do the same thing to the
children:

```js
function invertTree(node) {
  if (node === null) {
    return null;
  }

  [node.left, node.right] = [node.right, node.left];

  invertTree(node.left);
  invertTree(node.right);

  return node;
}
```

Every node is visited once, so this takes `O(n)` time. The recursive call stack
uses `O(h)` space, where `h` is the tree's height. On a very deep, unbalanced
tree, that stack depth matters.

The code is small. The useful question is why it works: a tree is made of
smaller trees. Swap the two subtrees at this node, then solve the same problem
for each one. When a subtree is empty, there is nothing to do.

### Use a queue instead

If you'd rather avoid recursion, visit the nodes breadth-first. An index into
the queue avoids repeatedly removing its first element:

```js
function invertTree(root) {
  if (root === null) {
    return null;
  }

  const queue = [root];

  for (let head = 0; head < queue.length; head++) {
    const node = queue[head];

    [node.left, node.right] = [node.right, node.left];

    if (node.left) queue.push(node.left);
    if (node.right) queue.push(node.right);
  }

  return root;
}
```

Same result, different traversal strategy. The queue can hold `O(w)` nodes,
where `w` is the tree's maximum width.

### Change one requirement

Now suppose the original tree must stay untouched. Swapping child references
doesn't meet that requirement; we need to build a new tree:

```js
function invertedCopy(node) {
  if (node === null) {
    return null;
  }

  return {
    value: node.value,
    left: invertedCopy(node.right),
    right: invertedCopy(node.left)
  };
}
```

One small change has brought up mutation, object references, memory use, and API
expectations. That's a better conversation than asking someone to recite the
swap from memory.

## So, what is a binary trie?

A regular trie stores strings by their prefixes. For `car`, `cat`, and `can`,
the shared path is `ca`; the branches only appear where the words differ.

Now imagine the alphabet has only two symbols:

```text
0 1
```

That's a binary trie. Each node has at most two children, one for each bit.
Insert the numbers `5` and `6`, written in binary as `101` and `110`:

```text
root
 └─ 1
    ├─ 0 ─ 1   (5)
    └─ 1 ─ 0   (6)
```

Here is a small JavaScript implementation for **unsigned 32-bit integers**:

```js
class BinaryTrieNode {
  constructor() {
    this.children = [null, null];
  }
}

class BinaryTrie {
  constructor() {
    this.root = new BinaryTrieNode();
  }

  insert(number) {
    let node = this.root;

    for (let bit = 31; bit >= 0; bit--) {
      const value = (number >>> bit) & 1;

      if (!node.children[value]) {
        node.children[value] = new BinaryTrieNode();
      }

      node = node.children[value];
    }
  }
}
```

This expression extracts one bit:

```js
const bit = (number >>> position) & 1;
```

For `5` (`101`), positions zero through two contain `1`, `0`, and `1`. JavaScript
bitwise operations on `Number` values use 32-bit integer representations, so
this example is deliberately limited to unsigned 32-bit inputs. `BigInt` supports
bitwise operations without that 32-bit truncation, but it does not support
unsigned right shift (`>>>`). See [MDN's bitwise operator guide](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Expressions_and_operators#bitwise_operators).

## Use the trie to maximize XOR

XOR gives `1` when two bits differ and `0` when they match:

```text
  101
^ 011
-----
  110
```

So, when comparing two numbers, each bit contributes most if we can find the
opposite bit in the other number. A binary trie lets us try that choice from
the most significant bit down:

```js
class BinaryTrie {
  constructor() {
    this.root = new BinaryTrieNode();
  }

  insert(number) {
    let node = this.root;

    for (let bit = 31; bit >= 0; bit--) {
      const value = (number >>> bit) & 1;

      if (!node.children[value]) {
        node.children[value] = new BinaryTrieNode();
      }

      node = node.children[value];
    }
  }

  findMaxXor(number) {
    let node = this.root;
    let result = 0;

    for (let bit = 31; bit >= 0; bit--) {
      const current = (number >>> bit) & 1;
      const wanted = current ^ 1;

      if (node.children[wanted]) {
        result += 2 ** bit;
        node = node.children[wanted];
      } else {
        node = node.children[current];
      }
    }

    return result;
  }
}
```

Each lookup tries the opposite branch first. If that branch exists, this bit
can contribute `1` to the XOR result; otherwise, we follow the matching bit.
The lookup takes `O(32)` time for this fixed-width example.

To find the maximum XOR pair in a list, query each number against values
already inserted, then insert it. Starting with an empty trie means a number
isn't compared with itself:

```js
function maxPairXor(numbers) {
  const trie = new BinaryTrie();
  let maximum = 0;

  for (const number of numbers) {
    if (trie.root.children[0] || trie.root.children[1]) {
      maximum = Math.max(maximum, trie.findMaxXor(number));
    }

    trie.insert(number);
  }

  return maximum;
}
```

For `n` values, this takes `O(32n)` time and stores up to `O(32n)` trie nodes.
For a small input, the straightforward nested loop is simpler and may be the
right choice. Specialize when the constraints give you a reason.

## Where prefix structures show up

Autocomplete is an intuitive example. Given `checkout`, `commit`, `clone`,
`cherry-pick`, and `clean`, a trie can take us to the `ch` prefix and then
collect words below that point. For a small list, though, I'd use
`commands.filter(command => command.startsWith("ch"))`. Don't reach for a
specialized index just because you learned its name.

Network routes are a more consequential prefix problem. Routes such as
`10.0.0.0/8`, `10.10.0.0/16`, and `10.10.20.0/24` overlap. A lookup needs the
most specific matching prefix. The Linux kernel documents its IPv4 forwarding
structure as an [LC-trie](https://kernel.org/doc/html/latest/networking/fib_trie.html)
that searches for the longest matching prefix.

Would I build the Linux routing table in JavaScript? No. But now the trie isn't
just an interview toy: it is one way to organize a real prefix-lookup problem.

## Ask a better interview question

Instead of opening with “Implement a binary trie,” start with a goal:

> Given a list of integers, find the maximum XOR of any pair.

A candidate might begin with the direct solution:

```js
function maxPairXorSlow(numbers) {
  let maximum = 0;

  for (let i = 0; i < numbers.length; i++) {
    for (let j = i + 1; j < numbers.length; j++) {
      maximum = Math.max(maximum, numbers[i] ^ numbers[j]);
    }
  }

  return maximum;
}
```

It's correct, and it takes `O(n²)` time. Ask what changes when the list grows.
Now there's a reason to discuss performance. Offer the observation that XOR
prefers opposite bits and see whether they can turn that into a useful
structure. If they haven't seen tries, explain the zero and one branches and
ask them to continue from there.

The useful signal isn't whether they remembered the data structure's name.
It's how they handle a new constraint, explain a trade-off, and work with a
hint.

The same follow-ups make tree questions more revealing:

- What are the time and space costs?
- Can you do it breadth-first?
- What changes if the input must remain immutable?
- What if the tree is millions of nodes deep?
- What if two parents can point to the same node?
- What if we only need to invert nodes through depth four?

Each question changes an assumption. Now the candidate can talk about stack
depth, memory, shared references, or graph traversal instead of reciting one
answer. That's the interesting part.

## Play with the weird stuff

My favorite way to learn a concept is to build the smallest version, break it,
change a requirement, and compare another approach:

```text
What is this?
↓
Build the simplest version.
↓
Change one assumption.
↓
Find where the idea helps in a real system.
```

Invert a tree. Then make a copy instead of mutating it. Build a word trie, then
replace the alphabet with `0` and `1`. Use it for XOR. Look at longest-prefix
matching in networking.

Somewhere along the way, “a random interview question” becomes “oh, that's why
someone invented this.” That's the fun part—and a much better signal in an
interview than a memorized answer.
