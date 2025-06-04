import Test "mo:base/test";
import Debug "mo:base/Debug";

actor {
  public func test_add() : async () {
    Debug.print("Testing addition");
    assert(1 + 2 == 3);
  };

  public func test_fail_example() : async () {
    Debug.print("This should fail if uncommented");
    
  };
};
