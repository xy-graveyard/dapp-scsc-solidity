## Steps to preparing an XYO Smart Contract to be upgradable through proxies using ZOS

**Install Zeppelin OS**
```bash
npm install --global zos
```

**Initiate the SCSC Library**
```bash
zos init dapp-scsc-solidity
```

`zos init` will create a `zos.json` file which should look something like this:

```json
{
  "zosversion": "2.2",
  "name": "dapp-scsc-solidity",
  "version": "0.1.0",
  "contracts": {}
}
```

The command will see that truffle is already initialized and configured so you shouldn't have to worry about any unecessary `migrations` or `contracts` being created.

For this contract please use the `development` settings from `truffle.js`

Since we are replacing constructors with initializers on any contract that we want to make upgradeable through this ZOS proxy method. We will have to import this specific contract from the ZOS library

```bash
npm install zos-lib
```

Then import at the top of your contract .sol file 

```bash
import "zos-lib/contracts/Initializable.sol";
```

Now we should make the contract initializable:

Replace the constructor 

```sol
    constructor(
    ) XyParameterizer() 
    public {
    }

    function init(
        address _resolverAddress,
        address _xyERC20,
        address _plcr,
        uint[] memory _parameters
    ) public {
        resolverAddress = _resolverAddress;
        super.init(_xyERC20, _plcr, _parameters);
    }
```

with this 

```sol
    function initialize(
        address _resolverAddress,
        address _xyERC20,
        address _plcr,
        uint[] memory _parameters
    ) public initializer {
        resolverAddress = _resolverAddress;
        super.init(_xyERC20, _plcr, _parameters);
    }
```

We also want to update the contracts we are bringing in:

```sol
contract XyGovernance is XyParameterizer {
```

to

```sol
contract XyGovernance is XyParameterizer, Initializable {
```

Also, we want to remove any unecessary initializations of state variables (including in ancestor contracts)

`XyGovernance.sol`
```sol 
bool ownershipRenounced = false;
```
change to
```sol
bool ownershipRenounced; // this defaults to false anyway
```

`XyParameterizer.sol`

```sol
uint public stageBlockLen = 40320;
```

change to 
```sol
uint public stageBlockLen;

//initialize value in the init function (stageBlockLen = 40320;)
```

Once we set up the contact with this initializer function, we now want to run a ganache environment

```bash
ganache-cli --port 8545 --deterministic
```

Now we should grab the last account from our accounts array, since we don't want to run any proxies to close to other accounts that would be used for any interactions with other contracts

Then we set up our ZOS session to prep and deploy our contracts

```bash
zos session --network development --from 0x1df62f291b2e969fb0849d99d9ce41e2f137006e --expires 3600
```

Now we add the contract

```bash
zos add XyGovernance
```
Now the `zos.json` file should be upgraded to this

```json
{
  "zosversion": "2.2",
  "name": "dapp-scsc-solidity",
  "version": "0.1.0",
  "contracts": {
    "XyGovernance": "XyGovernance"
  }
}
```

Now that we have linked our contract with the ZeppelinOS project, we deploy it to the development blockchain

```bash
zos push
```