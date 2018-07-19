
# coding: utf-8

# In[3]:


abi = """[
  {
    "constant": false,
    "inputs": [
      {
        "name": "_owner",
        "type": "address"
      },
      {
        "name": "_tokenVIN",
        "type": "string"
      },
      {
        "name": "_serializedData",
        "type": "bytes"
      },
      {
        "name": "_txHash",
        "type": "bytes32"
      }
    ],
    "name": "transferApproved",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "name": "_from",
        "type": "address"
      },
      {
        "indexed": false,
        "name": "_tokenVIN",
        "type": "string"
      },
      {
        "indexed": false,
        "name": "_data",
        "type": "bytes"
      }
    ],
    "name": "UserRequestForSignature",
    "type": "event"
  }
]"""


# In[4]:


from web3 import Web3, HTTPProvider
import time
#pk = ("lifhfrn1lkjs4slkvrgnldd8ijsrlv94").encode("utf-8").hex()
pk = "0x6c69666866726e316c6b6a7334736c6b7672676e6c646438696a73726c763934"
w3Sokol = Web3(HTTPProvider("https://sokol.poa.network"))
w3Kovan = Web3(HTTPProvider("https://kovan.infura.io/mew"))
acct = w3Sokol.eth.account.privateKeyToAccount(pk)
w3Kovan.eth.getBalance(Web3.toChecksumAddress(acct.address))


# In[5]:


homeAddress = Web3.toChecksumAddress("0x2f90d922f8147d9f5f4006a587f9605a6fcd927f")
foreignAddress = Web3.toChecksumAddress("0x2f90d922f8147d9f5f4006a587f9605a6fcd927f")
homeBridge = w3Sokol.eth.contract (
    abi=abi,
    address=homeAddress
)
foreignBridge = w3Sokol.eth.contract (
    abi=abi,
    address=foreignAddress
)
lastProcessedForeignBlock = 0
lastProcessedHomeBlock = 0


# In[ ]:


while True:
    filter_home = {
        "fromBlock": lastProcessedForeignBlock,
        "toBlock": "latest",
        "address": homeAddress
    }
    logs = w3Sokol.eth.getLogs(filter_home)
    for i in logs:
        receipt = w3Sokol.eth.getTransactionReceipt(i['transactionHash'])
        events = homeBridge.events.UserRequestForSignature().processReceipt(receipt)
        #print(events[0])
        for ev in events:
            nonce = w3Kovan.eth.getTransactionCount(acct.address)
            tx_foreign = {
                "gas": 7000000,
                "gasPrice": Web3.toWei(1, "gwei"),
                "nonce": nonce
            }
            tx = foreignBridge.functions.transferApproved(
                ev.args['_from'],
                ev.args['_tokenVIN'],
                ev.args['_data'],
                ev['transactionHash']
            ).buildTransaction(tx_foreign)
            signed_tx = acct.signTransaction(tx)
            tx_hash = w3Kovan.eth.sendRawTransaction(signed_tx.rawTransaction)
            w3Kovan.eth.waitForTransactionReceipt(tx_hash)
            print("Sokol->Kovan" + tx_hash.hex())
    lastProcessedForeignBlock = receipt.blockNumber+1
    filter_foreign = {
        "fromBlock": lastProcessedHomeBlock,
        "toBlock": "latest",
        "address": foreignAddress
    }
    logs = w3Kovan.eth.getLogs(filter_foreign)
    for i in logs:
        receipt = w3Kovan.eth.getTransactionReceipt(i['transactionHash'])
        events = foreignBridge.events.UserRequestForSignature().processReceipt(receipt)
        for ev in events:
            nonce = w3Sokol.eth.getTransactionCount(acct.address)
            tx_home = {
                "gas": 7000000,
                "gasPrice": Web3.toWei(1, "gwei"),
                "nonce": nonce
            }
            tx = homeBridge.functions.transferApproved(
                ev.args['_from'],
                ev.args['_tokenVIN'],
                ev.args['_data'],
                ev['transactionHash']
            ).buildTransaction(tx_home)
            signed_tx = acct.signTransaction(tx)
            tx_hash = w3Sokol.eth.sendRawTransaction(signed_tx.rawTransaction)
            w3Sokol.eth.waitForTransactionReceipt(tx_hash)
            print("Kovan->Sokol" + tx_hash.hex())
    time.sleep(5)

