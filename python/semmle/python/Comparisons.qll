// Copyright 2016 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.


import python

/* A class representing the six comparison operators, ==, !=, <, <=, > and >=.
 *  */
class CompareOp extends int {

    CompareOp() { 
        this.(int) in [1..6]
    }

    /** Gets the logical inverse operator */
    CompareOp invert() {
        this = eq() and result = ne() or
        this = ne() and result = eq() or
        this = lt() and result = ge() or
        this = gt() and result = le() or
        this = le() and result = gt() or
        this = ge() and result = lt()
    }

    /** Gets the reverse operator (swapping the operands) */ 
    CompareOp reverse() {
        this = eq() and result = eq() or
        this = ne() and result = ne() or
        this = lt() and result = gt() or
        this = gt() and result = lt() or
        this = le() and result = ge() or
        this = ge() and result = le()
    }

    string repr() {
        this = eq() and result = "==" or
        this = ne() and result = "!=" or
        this = lt() and result = "<" or
        this = gt() and result = ">" or
        this = le() and result = "<=" or
        this = ge() and result = ">="
    }

    predicate forOp(Cmpop op) {
        op instanceof Eq and this = eq() or
        op instanceof NotEq and this = ne() or
        op instanceof Lt and this = lt() or
        op instanceof LtE and this = le() or
        op instanceof Gt and this = gt() or
        op instanceof GtE and this = ge()
    }

    /** Return this if isTrue is true, otherwise returns the inverse */
    CompareOp conditional(boolean isTrue) {
        result = this and isTrue = true
        or
        result = this.invert() and isTrue = false
    }

}

CompareOp eq() { result = 1 }
CompareOp ne() { result = 2 }
CompareOp lt() { result = 3 }
CompareOp le() { result = 4 }
CompareOp gt() { result = 5 }
CompareOp ge() { result = 6 }


/** Normalise equality cmp into the form `left op right + k`. */
private predicate test(ControlFlowNode cmp, ControlFlowNode left, CompareOp op, ControlFlowNode right, float k) {
    simple_test(cmp, left, op, right) and k = 0
    or
    add_test(cmp, left, op, right, k)
    or
    not_test(cmp, left, op, right, k)
    or
    subtract_test(cmp, left, op, right, k)
    or
    exists(float c | test(cmp, right, op.reverse(), left, c) and k = -c)
}

/** Various simple tests in left op right + k form. */
private predicate simple_test(CompareNode cmp, ControlFlowNode l, CompareOp cmpop, ControlFlowNode r) {
    exists(Cmpop op |
        cmp.operands(l, op, r) and cmpop.forOp(op)
    )
}

/* left + x op right + c => left op right + (c-x)
   left op (right + x) + c => left op right + (c+x) */
private predicate add_test(CompareNode cmp, ControlFlowNode l, CompareOp op, ControlFlowNode r, float k) {
    exists(BinaryExprNode lhs, float c, float x, Num n |
        lhs.getNode().getOp() instanceof Add and
        test(cmp, lhs, op, r, c) and x = n.getN().toFloat() and k = c - x |
        l = lhs.getLeft() and n = lhs.getRight().getNode()
        or
        l = lhs.getRight() and n = lhs.getLeft().getNode()
    )
    or
    exists(BinaryExprNode rhs, float c, float x, Num n |
        rhs.getNode().getOp() instanceof Add and
        test(cmp, l, op, rhs, c) and x = n.getN().toFloat() and k = c + x |
        r = rhs.getLeft() and n = rhs.getRight().getNode()
        or
        r = rhs.getRight() and n = rhs.getLeft().getNode()
    )
}

/* left - x op right + c => left op right + (c+x) 
   left op (right - x) + c => left op right + (c-x) */
private predicate subtract_test(CompareNode cmp, ControlFlowNode l, CompareOp op, ControlFlowNode r, float k) {
    exists(BinaryExprNode lhs, float c, float x, Num n |
        lhs.getNode().getOp() instanceof Sub and
        test(cmp, lhs, op, r, c) and
        l = lhs.getLeft() and n = lhs.getRight().getNode() and
        x = n.getN().toFloat() |
        k = c + x
    )
    or
    exists(BinaryExprNode rhs, float c, float x, Num n |
        rhs.getNode().getOp() instanceof Sub and
        test(cmp, l, op, rhs, c) and
        r = rhs.getRight() and n = rhs.getLeft().getNode() and
        x = n.getN().toFloat() |
        k = c - x
    )
}

private predicate not_test(UnaryExprNode u, ControlFlowNode l, CompareOp op, ControlFlowNode r, float k) {
    u.getNode().getOp() instanceof Not
    and
    test(u.getOperand(), l, op.invert(), r, k)
}


/** A comparison which can be simplified to the canonical form `x OP y + k` where `x` and `y` are `ControlFlowNode`s, 
 * `k` is a floating point constant and `OP` is one of `<=`, `>`, `==` or `!=`.
 */
class Comparison extends ControlFlowNode {

    Comparison() {
        test(this, _, _, _, _)
    }

    /** Whether this condition tests `l op r + k` */
    predicate tests(ControlFlowNode l, CompareOp op, ControlFlowNode r, float k) {
        test(this, l, op, r, k)
    }

    /** Whether this condition tests `l op k` */
    predicate tests(ControlFlowNode l, CompareOp op, float k) {
        exists(ControlFlowNode r, float x, float c |
            test(this, l, op, r, c) |
            x = r.getNode().(Num).getN().toFloat() and
            k = c + x
        )
    }

    /* The following predicates determine whether this test, when its result is `thisIsTrue`,
     * is equivalent to the predicate `v OP k` or `v1 OP v2 + k`.
     * For example, the test `x <= y` being false, is equivalent to the predicate `x > y`.
     */

    private predicate equivalentToEq(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), eq().conditional(thisIsTrue), k)
    }

    private predicate equivalentToNotEq(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), ne().conditional(thisIsTrue), k)
    }

    private predicate equivalentToLt(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), lt().conditional(thisIsTrue), k)
    }

    private predicate equivalentToLtEq(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), le().conditional(thisIsTrue), k)
    }

    private predicate equivalentToGt(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), gt().conditional(thisIsTrue), k)
    }

    private predicate equivalentToGtEq(boolean thisIsTrue, SsaVariable v, float k) {
        this.tests(v.getAUse(), ge().conditional(thisIsTrue), k)
    }

    private predicate equivalentToEq(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), eq().conditional(thisIsTrue), v2.getAUse(), k)
    }

    private predicate equivalentToNotEq(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), ne().conditional(thisIsTrue), v2.getAUse(), k)
    }

    private predicate equivalentToLt(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), lt().conditional(thisIsTrue), v2.getAUse(), k)
    }

    private predicate equivalentToLtEq(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), le().conditional(thisIsTrue), v2.getAUse(), k)
    }

    private predicate equivalentToGt(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), gt().conditional(thisIsTrue), v2.getAUse(), k)
    }

    private predicate equivalentToGtEq(boolean thisIsTrue, SsaVariable v1, SsaVariable v2, float k) {
        this.tests(v1.getAUse(), ge().conditional(thisIsTrue), v2.getAUse(), k)
    }

    /** Whether the result of this comparison being `thisIsTrue` implies that the result of `that` is `isThatTrue`.
     * In other words, does the predicate that is equivalent to the result of `this` being `thisIsTrue`
     * imply the predicate that is equivalent to the result of `that` being `thatIsTrue`.
     * For example, assume that there are two tests, which when normalised have the form `x < y` and `x > y + 1`.
     * Then the test `x < y` having a true result, implies that the test `x > y + 1` will have a false result.
     * (`x < y` having a false result implies nothing about `x > y + 1`)
     */
    predicate impliesThat(boolean thisIsTrue, Comparison that, boolean thatIsTrue) {
        /* `v == k` => `v == k` */
        exists(SsaVariable v, float k |
            this.equivalentToEq(thisIsTrue, v, k) and
            that.equivalentToEq(thatIsTrue, v, k)
            or
            this.equivalentToNotEq(thisIsTrue, v, k) and
            that.equivalentToNotEq(thatIsTrue, v, k)
        )
        or
        exists(SsaVariable v, float k1, float k2 |
            /* `v < k1` => `v != k2` iff k1 <= k2 */
            this.equivalentToLt(thisIsTrue, v, k1) and
            that.equivalentToNotEq(thatIsTrue, v, k2) and
            k1 <= k2
            or
            /* `v <= k1` => `v != k2` iff k1 < k2 */
            this.equivalentToLtEq(thisIsTrue, v, k1) and
            that.equivalentToNotEq(thatIsTrue, v, k2) and
            k1 < k2
            or
            /* `v > k1` => `v != k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v, k1) and
            that.equivalentToNotEq(thatIsTrue, v, k2) and
            k1 >= k2
            or
            /* `v >= k1` => `v != k2` iff k1 > k2 */
            this.equivalentToGtEq(thisIsTrue, v, k1) and
            that.equivalentToNotEq(thatIsTrue, v, k2) and
            k1 > k2
        )
        or
        exists(SsaVariable v, float k1, float k2 |
            /* `v < k1` => `v < k2` iff k1 <= k2 */
            this.equivalentToLt(thisIsTrue, v, k1) and
            that.equivalentToLt(thatIsTrue, v, k2) and
            k1 <= k2
            or
            /* `v < k1` => `v <= k2` iff k1 <= k2 */
            this.equivalentToLt(thisIsTrue, v, k1) and
            that.equivalentToLtEq(thatIsTrue, v, k2) and
            k1 <= k2
            or
            /* `v <= k1` => `v < k2` iff k1 < k2 */
            this.equivalentToLtEq(thisIsTrue, v, k1) and
            that.equivalentToLt(thatIsTrue, v, k2) and
            k1 < k2
            or
            /* `v <= k1` => `v <= k2` iff k1 <= k2 */
            this.equivalentToLtEq(thisIsTrue, v, k1) and
            that.equivalentToLtEq(thatIsTrue, v, k2) and
            k1 <= k2
        )
        or
        exists(SsaVariable v, float k1, float k2 |
            /* `v > k1` => `v >= k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v, k1) and
            that.equivalentToGt(thatIsTrue, v, k2) and
            k1 >= k2
            or
            /* `v > k1` => `v >= k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v, k1) and
            that.equivalentToGtEq(thatIsTrue, v, k2) and
            k1 >= k2
             or
            /* `v >= k1` => `v > k2` iff k1 > k2 */
            this.equivalentToGtEq(thisIsTrue, v, k1) and
            that.equivalentToGt(thatIsTrue, v, k2) and
            k1 > k2
            or
            /* `v >= k1` => `v >= k2` iff k1 >= k2 */
            this.equivalentToGtEq(thisIsTrue, v, k1) and
            that.equivalentToGtEq(thatIsTrue, v, k2) and
            k1 >= k2
        )
        or
        exists(SsaVariable v1, SsaVariable v2, float k |
            /* `v1 == v2 + k` => `v1 == v2 + k` */
            this.equivalentToEq(thisIsTrue, v1, v2, k) and
            that.equivalentToEq(thatIsTrue, v1, v2, k)
            or
            this.equivalentToNotEq(thisIsTrue, v1, v2, k) and
            that.equivalentToNotEq(thatIsTrue, v1, v2, k)
        )
        or
        exists(SsaVariable v1, SsaVariable v2, float k1, float k2 |
            /* `v1 < v2 + k1` => `v1 != v2 + k2` iff k1 <= k2 */
            this.equivalentToLt(thisIsTrue, v1, v2, k1) and
            that.equivalentToNotEq(thatIsTrue, v1, v2, k2) and
            k1 <= k2
            or
            /* `v1 <= v2 + k1` => `v1 != v2 + k2` iff k1 < k2 */
            this.equivalentToLtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToNotEq(thatIsTrue, v1, v2, k2) and
            k1 < k2
            or
            /* `v1 > v2 + k1` => `v1 != v2 + k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v1, v2, k1) and
            that.equivalentToNotEq(thatIsTrue, v1, v2, k2) and
            k1 >= k2
            or
            /* `v1 >= v2 + k1` => `v1 != v2 + k2` iff k1 > k2 */
            this.equivalentToGtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToNotEq(thatIsTrue, v1, v2, k2) and
            k1 > k2
        )
        or
        exists(SsaVariable v1, SsaVariable v2, float k1, float k2 |
            /* `v1 <= v2 + k1` => `v1 <= v2 + k2` iff k1 <= k2 */
            this.equivalentToLtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToLtEq(thatIsTrue, v1, v2, k2) and
            k1 <= k2
            or
            /* `v1 < v2 + k1` => `v1 <= v2 + k2` iff k1 <= k2 */
            this.equivalentToLt(thisIsTrue, v1, v2, k1) and
            that.equivalentToLtEq(thatIsTrue, v1, v2, k2) and
            k1 <= k2
            or
            /* `v1 <= v2 + k1` => `v1 < v2 + k2` iff k1 < k2 */
            this.equivalentToLtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToLt(thatIsTrue, v1, v2, k2) and
            k1 < k2
            or
            /* `v1 <= v2 + k1` => `v1 <= v2 + k2` iff k1 <= k2 */
            this.equivalentToLtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToLtEq(thatIsTrue, v1, v2, k2) and
            k1 <= k2
        )
        or
        exists(SsaVariable v1, SsaVariable v2, float k1, float k2 |
            /* `v1 > v2 + k1` => `v1 > v2 + k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v1, v2, k1) and
            that.equivalentToGt(thatIsTrue, v1, v2, k2) and
            k1 >= k2
            or
            /* `v1 > v2 + k1` => `v2 >= v2 + k2` iff k1 >= k2 */
            this.equivalentToGt(thisIsTrue, v1, v2, k1) and
            that.equivalentToGtEq(thatIsTrue, v1, v2, k2) and
            k1 >= k2
            or
            /* `v1 >= v2 + k1` => `v2 > v2 + k2` iff k1 > k2 */
            this.equivalentToGtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToGt(thatIsTrue, v1, v2, k2) and
            k1 > k2
            or
            /* `v1 >= v2 + k1` => `v2 >= v2 + k2` iff k1 >= k2 */
            this.equivalentToGtEq(thisIsTrue, v1, v2, k1) and
            that.equivalentToGtEq(thatIsTrue, v1, v2, k2) and
            k1 >= k2
        )
    }

}

/** A basic block which terminates in a condition, splitting the subsequent control flow, 
 * in which the condition is an instance of `Comparison`
 */
class ComparisonControlBlock extends ConditionBlock {

    ComparisonControlBlock() {
        this.getLastNode() instanceof Comparison
    }

    /** Whether this conditional guard determines that, in block `b`, `l == r + k` if `eq` is true, or `l != r + k` if `eq` is false, */
    predicate controls(ControlFlowNode l, CompareOp op, ControlFlowNode r, float k, BasicBlock b) {
        exists(boolean control |
            this.controls(b, control) and this.getTest().tests(l, op, r, k) and control = true
            or
            this.controls(b, control) and this.getTest().tests(l, op.invert(), r, k) and control = false
        )
    }

    /** Whether this conditional guard determines that, in block `b`, `l == r + k` if `eq` is true, or `l != r + k` if `eq` is false, */
    predicate controls(ControlFlowNode l, CompareOp op, float k, BasicBlock b) {
        exists(boolean control |
            this.controls(b, control) and this.getTest().tests(l, op, k) and control = true
            or
            this.controls(b, control) and this.getTest().tests(l, op.invert(), k) and control = false
        )
    }

    Comparison getTest() {
        this.getLastNode() = result
    }

    /** Whether this conditional guard implies that, in block `b`,  the result of `that` is `thatIsTrue` */
    predicate impliesThat(BasicBlock b, Comparison that, boolean thatIsTrue) {
        exists(boolean controlSense |
            this.controls(b, controlSense) and 
            this.getTest().impliesThat(controlSense, that, thatIsTrue)
        )
    }

}
