import { ethereum } from "@graphprotocol/graph-ts"
import { Protocol } from "../generated/schema"

export function handleBlock(block: ethereum.Block): void {
  let p = Protocol.load("1")
  if (p == null) {
    p = new Protocol("1")
  }
  p.n = block.number
  p.tag = "__TAG__"
  p.save()
}
