// Copyright 2015 Stellar Development Foundation and contributors. Licensed
// under the Apache License, Version 2.0. See the COPYING file at the root
// of this distribution or at http://www.apache.org/licenses/LICENSE-2.0

%#include "xdr/Stellar-types.h"
%#include "xdr/Stellar-contract.h"

namespace stellar
{

typedef opaque Thresholds[4];
typedef string string32<32>;
typedef string string64<64>;
typedef int64 SequenceNumber;
typedef opaque DataValue<64>;
typedef Hash PoolID; // SHA256(LiquidityPoolParameters)

// 1-4 alphanumeric characters right-padded with 0 bytes
typedef opaque AssetCode4[4];

// 5-12 alphanumeric characters right-padded with 0 bytes
typedef opaque AssetCode12[12];

enum AssetType
{
    ASSET_TYPE_NATIVE = 0,
    ASSET_TYPE_CREDIT_ALPHANUM4 = 1,
    ASSET_TYPE_CREDIT_ALPHANUM12 = 2,
    ASSET_TYPE_POOL_SHARE = 3
};

union AssetCode switch (AssetType type)
{
case ASSET_TYPE_CREDIT_ALPHANUM4:
    AssetCode4 assetCode4;

case ASSET_TYPE_CREDIT_ALPHANUM12:
    AssetCode12 assetCode12;

    // add other asset types here in the future
};

struct AlphaNum4
{
    AssetCode4 assetCode;
    AccountID issuer;
};

struct AlphaNum12
{
    AssetCode12 assetCode;
    AccountID issuer;
};

union Asset switch (AssetType type)
{
case ASSET_TYPE_NATIVE: // Not credit
    void;

case ASSET_TYPE_CREDIT_ALPHANUM4:
    AlphaNum4 alphaNum4;

case ASSET_TYPE_CREDIT_ALPHANUM12:
    AlphaNum12 alphaNum12;

    // add other asset types here in the future
};

// price in fractional representation
struct Price
{
    int32 n; // numerator
    int32 d; // denominator
};

struct Liabilities
{
    int64 buying;
    int64 selling;
};

// the 'Thresholds' type is packed uint8_t values
// defined by these indexes
enum ThresholdIndexes
{
    THRESHOLD_MASTER_WEIGHT = 0,
    THRESHOLD_LOW = 1,
    THRESHOLD_MED = 2,
    THRESHOLD_HIGH = 3
};

enum LedgerEntryType
{
    ACCOUNT = 0,
    TRUSTLINE = 1,
    OFFER = 2,
    DATA = 3,
    CLAIMABLE_BALANCE = 4,
    LIQUIDITY_POOL = 5,
    CONTRACT_DATA = 6,
    CONTRACT_CODE = 7,
    CONFIG_SETTING = 8
};

struct Signer
{
    SignerKey key;
    uint32 weight; // really only need 1 byte
};

enum AccountFlags
{ // masks for each flag

    // Flags set on issuer accounts
    // TrustLines are created with authorized set to "false" requiring
    // the issuer to set it for each TrustLine
    AUTH_REQUIRED_FLAG = 0x1,
    // If set, the authorized flag in TrustLines can be cleared
    // otherwise, authorization cannot be revoked
    AUTH_REVOCABLE_FLAG = 0x2,
    // Once set, causes all AUTH_* flags to be read-only
    AUTH_IMMUTABLE_FLAG = 0x4,
    // Trustlines are created with clawback enabled set to "true",
    // and claimable balances created from those trustlines are created
    // with clawback enabled set to "true"
    AUTH_CLAWBACK_ENABLED_FLAG = 0x8
};

// mask for all valid flags
const MASK_ACCOUNT_FLAGS = 0x7;
const MASK_ACCOUNT_FLAGS_V17 = 0xF;

// maximum number of signers
const MAX_SIGNERS = 20;

typedef AccountID* SponsorshipDescriptor;

struct AccountEntryExtensionV3
{
    // We can use this to add more fields, or because it is first, to
    // change AccountEntryExtensionV3 into a union.
    ExtensionPoint ext;

    // Ledger number at which `seqNum` took on its present value.
    uint32 seqLedger;

    // Time at which `seqNum` took on its present value.
    TimePoint seqTime;
};

struct AccountEntryExtensionV2
{
    uint32 numSponsored;
    uint32 numSponsoring;
    SponsorshipDescriptor signerSponsoringIDs<MAX_SIGNERS>;

    union switch (int v)
    {
    case 0:
        void;
    case 3:
        AccountEntryExtensionV3 v3;
    }
    ext;
};

struct AccountEntryExtensionV1
{
    Liabilities liabilities;

    union switch (int v)
    {
    case 0:
        void;
    case 2:
        AccountEntryExtensionV2 v2;
    }
    ext;
};

/* AccountEntry

    Main entry representing a user in Stellar. All transactions are
    performed using an account.

    Other ledger entries created require an account.

*/
struct AccountEntry
{
    AccountID accountID;      // master public key for this account
    int64 balance;            // in stroops
    SequenceNumber seqNum;    // last sequence number used for this account
    uint32 numSubEntries;     // number of sub-entries this account has
                              // drives the reserve
    AccountID* inflationDest; // Account to vote for during inflation
    uint32 flags;             // see AccountFlags

    string32 homeDomain; // can be used for reverse federation and memo lookup

    // fields used for signatures
    // thresholds stores unsigned bytes: [weight of master|low|medium|high]
    Thresholds thresholds;

    Signer signers<MAX_SIGNERS>; // possible signers for this account

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    case 1:
        AccountEntryExtensionV1 v1;
    }
    ext;
};

/* TrustLineEntry
    A trust line represents a specific trust relationship with
    a credit/issuer (limit, authorization)
    as well as the balance.
*/

enum TrustLineFlags
{
    // issuer has authorized account to perform transactions with its credit
    AUTHORIZED_FLAG = 1,
    // issuer has authorized account to maintain and reduce liabilities for its
    // credit
    AUTHORIZED_TO_MAINTAIN_LIABILITIES_FLAG = 2,
    // issuer has specified that it may clawback its credit, and that claimable
    // balances created with its credit may also be clawed back
    TRUSTLINE_CLAWBACK_ENABLED_FLAG = 4
};

// mask for all trustline flags
const MASK_TRUSTLINE_FLAGS = 1;
const MASK_TRUSTLINE_FLAGS_V13 = 3;
const MASK_TRUSTLINE_FLAGS_V17 = 7;

enum LiquidityPoolType
{
    LIQUIDITY_POOL_CONSTANT_PRODUCT = 0
};

union TrustLineAsset switch (AssetType type)
{
case ASSET_TYPE_NATIVE: // Not credit
    void;

case ASSET_TYPE_CREDIT_ALPHANUM4:
    AlphaNum4 alphaNum4;

case ASSET_TYPE_CREDIT_ALPHANUM12:
    AlphaNum12 alphaNum12;

case ASSET_TYPE_POOL_SHARE:
    PoolID liquidityPoolID;

    // add other asset types here in the future
};

struct TrustLineEntryExtensionV2
{
    int32 liquidityPoolUseCount;

    union switch (int v)
    {
    case 0:
        void;
    }
    ext;
};

struct TrustLineEntry
{
    AccountID accountID;  // account this trustline belongs to
    TrustLineAsset asset; // type of asset (with issuer)
    int64 balance;        // how much of this asset the user has.
                          // Asset defines the unit for this;

    int64 limit;  // balance cannot be above this
    uint32 flags; // see TrustLineFlags

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    case 1:
        struct
        {
            Liabilities liabilities;

            union switch (int v)
            {
            case 0:
                void;
            case 2:
                TrustLineEntryExtensionV2 v2;
            }
            ext;
        } v1;
    }
    ext;
};

enum OfferEntryFlags
{
    // an offer with this flag will not act on and take a reverse offer of equal
    // price
    PASSIVE_FLAG = 1
};

// Mask for OfferEntry flags
const MASK_OFFERENTRY_FLAGS = 1;

/* OfferEntry
    An offer is the building block of the offer book, they are automatically
    claimed by payments when the price set by the owner is met.

    For example an Offer is selling 10A where 1A is priced at 1.5B

*/
struct OfferEntry
{
    AccountID sellerID;
    int64 offerID;
    Asset selling; // A
    Asset buying;  // B
    int64 amount;  // amount of A

    /* price for this offer:
        price of A in terms of B
        price=AmountB/AmountA=priceNumerator/priceDenominator
        price is after fees
    */
    Price price;
    uint32 flags; // see OfferEntryFlags

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    }
    ext;
};

/* DataEntry
    Data can be attached to accounts.
*/
struct DataEntry
{
    AccountID accountID; // account this data belongs to
    string64 dataName;
    DataValue dataValue;

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    }
    ext;
};

enum ClaimPredicateType
{
    CLAIM_PREDICATE_UNCONDITIONAL = 0,
    CLAIM_PREDICATE_AND = 1,
    CLAIM_PREDICATE_OR = 2,
    CLAIM_PREDICATE_NOT = 3,
    CLAIM_PREDICATE_BEFORE_ABSOLUTE_TIME = 4,
    CLAIM_PREDICATE_BEFORE_RELATIVE_TIME = 5
};

union ClaimPredicate switch (ClaimPredicateType type)
{
case CLAIM_PREDICATE_UNCONDITIONAL:
    void;
case CLAIM_PREDICATE_AND:
    ClaimPredicate andPredicates<2>;
case CLAIM_PREDICATE_OR:
    ClaimPredicate orPredicates<2>;
case CLAIM_PREDICATE_NOT:
    ClaimPredicate* notPredicate;
case CLAIM_PREDICATE_BEFORE_ABSOLUTE_TIME:
    int64 absBefore; // Predicate will be true if closeTime < absBefore
case CLAIM_PREDICATE_BEFORE_RELATIVE_TIME:
    int64 relBefore; // Seconds since closeTime of the ledger in which the
                     // ClaimableBalanceEntry was created
};

enum ClaimantType
{
    CLAIMANT_TYPE_V0 = 0
};

union Claimant switch (ClaimantType type)
{
case CLAIMANT_TYPE_V0:
    struct
    {
        AccountID destination;    // The account that can use this condition
        ClaimPredicate predicate; // Claimable if predicate is true
    } v0;
};

enum ClaimableBalanceIDType
{
    CLAIMABLE_BALANCE_ID_TYPE_V0 = 0
};

union ClaimableBalanceID switch (ClaimableBalanceIDType type)
{
case CLAIMABLE_BALANCE_ID_TYPE_V0:
    Hash v0;
};

enum ClaimableBalanceFlags
{
    // If set, the issuer account of the asset held by the claimable balance may
    // clawback the claimable balance
    CLAIMABLE_BALANCE_CLAWBACK_ENABLED_FLAG = 0x1
};

const MASK_CLAIMABLE_BALANCE_FLAGS = 0x1;

struct ClaimableBalanceEntryExtensionV1
{
    union switch (int v)
    {
    case 0:
        void;
    }
    ext;

    uint32 flags; // see ClaimableBalanceFlags
};

struct ClaimableBalanceEntry
{
    // Unique identifier for this ClaimableBalanceEntry
    ClaimableBalanceID balanceID;

    // List of claimants with associated predicate
    Claimant claimants<10>;

    // Any asset including native
    Asset asset;

    // Amount of asset
    int64 amount;

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    case 1:
        ClaimableBalanceEntryExtensionV1 v1;
    }
    ext;
};

struct LiquidityPoolConstantProductParameters
{
    Asset assetA; // assetA < assetB
    Asset assetB;
    int32 fee; // Fee is in basis points, so the actual rate is (fee/100)%
};

struct LiquidityPoolEntry
{
    PoolID liquidityPoolID;

    union switch (LiquidityPoolType type)
    {
    case LIQUIDITY_POOL_CONSTANT_PRODUCT:
        struct
        {
            LiquidityPoolConstantProductParameters params;

            int64 reserveA;        // amount of A in the pool
            int64 reserveB;        // amount of B in the pool
            int64 totalPoolShares; // total number of pool shares issued
            int64 poolSharesTrustLineCount; // number of trust lines for the
                                            // associated pool shares
        } constantProduct;
    }
    body;
};

struct ContractDataEntry {
    Hash contractID;
    SCVal key;
    SCVal val;
};

struct ContractCodeEntry {
    ExtensionPoint ext;

    Hash hash;
    opaque code<SCVAL_LIMIT>;
};

// Identifiers of all the network settings.
enum ConfigSettingID
{
    CONFIG_SETTING_CONTRACT_MAX_SIZE_BYTES = 0,
    CONFIG_SETTING_CONTRACT_COMPUTE_V0 = 1,
    CONFIG_SETTING_CONTRACT_LEDGER_COST_V0 = 2,
    CONFIG_SETTING_CONTRACT_HISTORICAL_DATA_V0 = 3,
    CONFIG_SETTING_CONTRACT_META_DATA_V0 = 4,
    CONFIG_SETTING_CONTRACT_BANDWIDTH_V0 = 5,
    CONFIG_SETTING_CONTRACT_HOST_LOGIC_VERSION = 6
};

// "Compute" settings for contracts (instructions and memory).
struct ConfigSettingContractComputeV0
{
    // Maximum instructions per ledger
    int64 ledgerMaxInstructions;
    // Maximum instructions per transaction
    int64 txMaxInstructions;
    // Cost of 10000 instructions
    int64 feeRatePerInstructionsIncrement;

    // Memory limit per contract/host function invocation. Unlike 
    // instructions, there is no fee for memory and it's not
    // accumulated between operations - the same limit is applied 
    // to every operation.
    uint32 memoryLimit;
};

// Ledger access settings for contracts.
struct ConfigSettingContractLedgerCostV0
{
    // Maximum number of ledger entry read operations per ledger
    uint32 ledgerMaxReadLedgerEntries;
    // Maximum number of bytes that can be read per ledger
    uint32 ledgerMaxReadBytes;
    // Maximum number of ledger entry write operations per ledger
    uint32 ledgerMaxWriteLedgerEntries;
    // Maximum number of bytes that can be written per ledger
    uint32 ledgerMaxWriteBytes;

    // Maximum number of ledger entry read operations per transaction
    uint32 txMaxReadLedgerEntries;
    // Maximum number of bytes that can be read per transaction
    uint32 txMaxReadBytes;
    // Maximum number of ledger entry write operations per transaction
    uint32 txMaxWriteLedgerEntries;
    // Maximum number of bytes that can be written per transaction
    uint32 txMaxWriteBytes;

    int64 feeReadLedgerEntry;  // Fee per ledger entry read
    int64 feeWriteLedgerEntry; // Fee per ledger entry write

    int64 feeRead1KB;  // Fee for reading 1KB    
    int64 feeWrite1KB; // Fee for writing 1KB

    // Bucket list fees grow slowly up to that size
    int64 bucketListSizeBytes;
    // Fee rate in stroops when the bucket list is empty
    int64 bucketListFeeRateLow;
    // Fee rate in stroops when the bucket list reached bucketListSizeBytes
    int64 bucketListFeeRateHigh;
    // Rate multiplier for any additional data past the first bucketListSizeBytes
    uint32 bucketListGrowthFactor;
};

// Historical data (pushed to core archives) settings for contracts.
struct ConfigSettingContractHistoricalDataV0
{
    int64 feeHistorical1KB; // Fee for storing 1KB in archives
};

// Meta data (pushed to downstream systems) settings for contracts.
struct ConfigSettingContractMetaDataV0
{
    // Maximum size of extended meta data produced by a transaction
    uint32 txMaxExtendedMetaDataSizeBytes;
    // Fee for generating 1KB of extended meta data
    int64 feeExtendedMetaData1KB;
};

// Bandwidth related data settings for contracts
struct ConfigSettingContractBandwidthV0
{
    // Maximum size in bytes to propagate per ledger
    uint32 ledgerMaxPropagateSizeBytes;
    // Maximum size in bytes for a transaction
    uint32 txMaxSizeBytes;

    // Fee for propagating 1KB of data
    int64 feePropagateData1KB;
};

union ConfigSettingEntry switch (ConfigSettingID configSettingID)
{
case CONFIG_SETTING_CONTRACT_MAX_SIZE_BYTES:
    uint32 contractMaxSizeBytes;
case CONFIG_SETTING_CONTRACT_COMPUTE_V0:
    ConfigSettingContractComputeV0 contractCompute;
case CONFIG_SETTING_CONTRACT_LEDGER_COST_V0:
    ConfigSettingContractLedgerCostV0 contractLedgerCost;
case CONFIG_SETTING_CONTRACT_HISTORICAL_DATA_V0:
    ConfigSettingContractHistoricalDataV0 contractHistoricalData;
case CONFIG_SETTING_CONTRACT_META_DATA_V0:
    ConfigSettingContractMetaDataV0 contractMetaData;
case CONFIG_SETTING_CONTRACT_BANDWIDTH_V0:
    ConfigSettingContractBandwidthV0 contractBandwidth;
case CONFIG_SETTING_CONTRACT_HOST_LOGIC_VERSION:
    uint32 contractHostLogicVersion;
};

struct LedgerEntryExtensionV1
{
    SponsorshipDescriptor sponsoringID;

    union switch (int v)
    {
    case 0:
        void;
    }
    ext;
};

struct LedgerEntry
{
    uint32 lastModifiedLedgerSeq; // ledger the LedgerEntry was last changed

    union switch (LedgerEntryType type)
    {
    case ACCOUNT:
        AccountEntry account;
    case TRUSTLINE:
        TrustLineEntry trustLine;
    case OFFER:
        OfferEntry offer;
    case DATA:
        DataEntry data;
    case CLAIMABLE_BALANCE:
        ClaimableBalanceEntry claimableBalance;
    case LIQUIDITY_POOL:
        LiquidityPoolEntry liquidityPool;
    case CONTRACT_DATA:
        ContractDataEntry contractData;
    case CONTRACT_CODE:
        ContractCodeEntry contractCode;
    case CONFIG_SETTING:
        ConfigSettingEntry configSetting;
    }
    data;

    // reserved for future use
    union switch (int v)
    {
    case 0:
        void;
    case 1:
        LedgerEntryExtensionV1 v1;
    }
    ext;
};

union LedgerKey switch (LedgerEntryType type)
{
case ACCOUNT:
    struct
    {
        AccountID accountID;
    } account;

case TRUSTLINE:
    struct
    {
        AccountID accountID;
        TrustLineAsset asset;
    } trustLine;

case OFFER:
    struct
    {
        AccountID sellerID;
        int64 offerID;
    } offer;

case DATA:
    struct
    {
        AccountID accountID;
        string64 dataName;
    } data;

case CLAIMABLE_BALANCE:
    struct
    {
        ClaimableBalanceID balanceID;
    } claimableBalance;

case LIQUIDITY_POOL:
    struct
    {
        PoolID liquidityPoolID;
    } liquidityPool;
case CONTRACT_DATA:
    struct
    {
        Hash contractID;
        SCVal key;
    } contractData;
case CONTRACT_CODE:
    struct
    {
        Hash hash;
    } contractCode;
case CONFIG_SETTING:
    struct
    {
        ConfigSettingID configSettingID;
    } configSetting;
};

// list of all envelope types used in the application
// those are prefixes used when building signatures for
// the respective envelopes
enum EnvelopeType
{
    ENVELOPE_TYPE_TX_V0 = 0,
    ENVELOPE_TYPE_SCP = 1,
    ENVELOPE_TYPE_TX = 2,
    ENVELOPE_TYPE_AUTH = 3,
    ENVELOPE_TYPE_SCPVALUE = 4,
    ENVELOPE_TYPE_TX_FEE_BUMP = 5,
    ENVELOPE_TYPE_OP_ID = 6,
    ENVELOPE_TYPE_POOL_REVOKE_OP_ID = 7,
    ENVELOPE_TYPE_CONTRACT_ID_FROM_ED25519 = 8,
    ENVELOPE_TYPE_CONTRACT_ID_FROM_CONTRACT = 9,
    ENVELOPE_TYPE_CONTRACT_ID_FROM_ASSET = 10,
    ENVELOPE_TYPE_CONTRACT_ID_FROM_SOURCE_ACCOUNT = 11,
    ENVELOPE_TYPE_CREATE_CONTRACT_ARGS = 12,
    ENVELOPE_TYPE_CONTRACT_AUTH = 13
};
}
