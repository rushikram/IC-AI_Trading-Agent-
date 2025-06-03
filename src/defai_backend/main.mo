import LLM "mo:llm";
import Array "mo:base/Array";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Buffer "mo:base/Buffer";
import Prompt "prompt";
import Swap "swap";

shared actor class AITradingAgent() = this {
  let swap = Swap.Swap(10000000000, 0);

  var priceCache : Buffer.Buffer<Float> = Buffer.Buffer<Float>(0);

  ignore Timer.recurringTimer<system>(
    #seconds 6,
    func() : async () {
      // check the amount of ckBTC we can swap for 1 ckUSDC from the mockup implementation
      let currentPrice = await swap.fetchCurrentPrice();
      priceCache.add(currentPrice);
      Debug.print("Current price: " # debug_show (currentPrice));
    },
  );

  ignore Timer.recurringTimer<system>(
    #seconds 36,
    func() : async () {

      // prepare the message for the LLM
      let content = "prices=" # debug_show (Buffer.toArray(priceCache)) # "\n" #
      "ckBTC=" # debug_show (swap.getCkBTC()) # "\n" #
      "ckUSDC=" # debug_show (swap.getCkUSDC()) # "\n";

      Debug.print("Prompt: \n" # content);

      let response = await LLM.chat(#Llama3_1_8B).withMessages([
        #system_ {
          content = Prompt.systemPrompt();
        },
        #user {
          content;
        },
      ]).send();

      let responseContent = switch (response.message.content) {
        case (?content) content;
        case null {
          Debug.print("No response");
          return;
        };
      };

      Debug.print("Response: \n" # responseContent);

      // if the response contains "HOLD", do nothing
      if (Text.startsWith(responseContent, #text "HOLD")) {
        return;
      } else {
        let instructions = Iter.toArray(Text.split(responseContent, #text ","));
        if (Array.size(instructions) != 2) {
          return;
        };
        let token = instructions[0];
        let ?amount = Nat.fromText(instructions[1]) else {
          Debug.print("Invalid amount");
          return;
        };

        ignore do ? {
          let price = priceCache.removeLast()!;
          swap.swap(token, amount, price);
        };

      };
      // empty the cache
      priceCache.clear();
    },
  );
};