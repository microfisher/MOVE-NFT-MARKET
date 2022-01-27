//assert(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));

address 0x1e0c830eF929e530DDcfA8d79f758d09 {
// address 0x1 {
module Market {
    use 0x1::Signer;
    use 0x1::NFT::{Self, NFT, Metadata, MintCapability,BurnCapability, UpdateCapability};
    use 0x1::NFTGallery;
    // use 0x1::CoreAddresses;
    use 0x1::Account;
    use 0x1::Timestamp;
    // use 0x1::NFTGallery;
    use 0x1::Token::{Self, Token};
    use 0x1::STC::STC;
    use 0x1::Event;
    use 0x1::Errors;
    use 0x1::Vector;
    use 0x1::Option::{Self, Option};

    const MARKET_ADDRESS: address = @0x1e0c830eF929e530DDcfA8d79f758d09;
    // const MARKET_ADDRESS: address = @0x1;

    //The market is closed
    const MARKET_LOCKED: u64 = 300;
    //The product has expired
    const MARKET_ITEM_EXPIRED: u64 = 301;
    //Invalid product quantity
    const MARKET_INVALID_QUANTITY: u64 = 302;
    const MARKET_INVALID_PRICE: u64 = 303;
    const MARKET_INVALID_INDEX: u64 = 304;
    //The auction is not over
    const MARKET_NOT_OVER: u64 = 305;
    const MARKET_INVALID_NFT_ID: u64 = 305;

    const MARKET_FEE_RATE: u128 = 3;

    //Products maximum effective bid
    const ARG_MAX_BID: u64 = 50;

    struct Market has key, store{
        counter: u64,
        is_lock: bool,
        funds: Token<STC>,
        cashier: address,
        fee_rate: u128,
        put_on_events: Event::EventHandle<PutOnEvent>,
        pull_off_events: Event::EventHandle<PullOffEvent>,
        bid_events: Event::EventHandle<BidEvent>,
        settlement_events: Event::EventHandle<SettlementEvent>,
        nfts: vector<NFT<GoodsNFTInfo, GoodsNFTBody>>,
    }

    struct GoodsNFTBody has store{
        //quantity
        quantity: u64,
    }

    //NFT ext info
    struct GoodsNFTInfo has copy, store, drop{
        ///has In kind
        has_in_kind: bool,
        /// type
        type: u64,
        // resource url
        resource_url: vector<u8>,
        ///creator email
        mail: vector<u8>,
    }

    struct Goods has store, drop{
        id: u128,
        //creator
        creator: address,
        //amount of put on
        amount: u64,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //last price
        last_price: u128,
        //sell amount
        sell_amount: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfo,
        bid_list: vector<BidData>,
    }

    struct BidData has copy, store, drop {
        buyer: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_count: u64,
        bid_time: u64,
        total_coin: u128,
    }

    //put on event
    struct PutOnEvent has drop, store {
        goods_id: u128,
        //seller
        owner: address,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //total amount
        amount: u64,
        // puton time
        put_on_time: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfo,
    }

    //pull off event
    struct PullOffEvent has drop, store {
        owner: address,
        goods_id: u128,
        nft_id: u64,
    }

    struct BidEvent has drop, store {
        bidder: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_time: u64,
    }

    struct SettlementEvent has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        bid_time: u64,
        time: u64,
    }

    //goods basket
    struct GoodsBasket has key, store{
        items: vector<Goods>,
    }

    struct GoodsNFTCapability has key {
        mint_cap: MintCapability<GoodsNFTInfo>,
        update_cap: UpdateCapability<GoodsNFTInfo>,
    }

    fun empty_info(): GoodsNFTInfo {
        GoodsNFTInfo {
            has_in_kind: false,
            type: 0,
            resource_url: Vector::empty(),
            mail: Vector::empty(),
        }
    }
    
    public fun init(sender: &signer, cashier: address) {        
        let _addr = check_market_owner(sender);
        
        // NFT::register<GoodsNFTInfo, GoodsNFTInfo>(sender, empty_info(), NFT::empty_meta());
        NFT::register_v2<GoodsNFTInfo>(sender, NFT::empty_meta());
        let mint_cap = NFT::remove_mint_capability<GoodsNFTInfo>(sender);
        let update_cap = NFT::remove_update_capability<GoodsNFTInfo>(sender);
        move_to(sender, GoodsNFTCapability{mint_cap, update_cap});
        
        move_to<Market>(sender, Market{
            counter: 0,
            is_lock: false,
            funds: Token::zero<STC>(),
            cashier: cashier,
            fee_rate: MARKET_FEE_RATE,
            put_on_events: Event::new_event_handle<PutOnEvent>(sender),
            pull_off_events: Event::new_event_handle<PullOffEvent>(sender),
            bid_events: Event::new_event_handle<BidEvent>(sender),
            settlement_events: Event::new_event_handle<SettlementEvent>(sender),
            nfts: Vector::empty<NFT<GoodsNFTInfo, GoodsNFTBody>>(),
        });
    }

    public fun upgrade(sender: &signer) acquires GoodsNFTCapability {
        let _addr = check_market_owner(sender);
        let cap = borrow_global_mut<GoodsNFTCapability>(_addr);
        NFT::upgrade_nft_type_info_from_v1_to_v2<GoodsNFTInfo, GoodsNFTInfo>(sender, &mut cap.mint_cap);
        let _nft_info = NFT::remove_compat_info<GoodsNFTInfo, GoodsNFTInfo>(&mut cap.mint_cap);
    }

    fun mint_nft(creator: address, receiver: address, quantity: u64, base_meta: Metadata, type_meta: GoodsNFTInfo): u64 acquires GoodsNFTCapability {
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let tm = copy type_meta;
        let md = copy base_meta;
        let nft = NFT::mint_with_cap<GoodsNFTInfo, GoodsNFTBody, GoodsNFTInfo>(creator, &mut cap.mint_cap, md, tm, GoodsNFTBody{quantity});
        let id = NFT::get_id(&nft);
        NFTGallery::deposit_to(receiver, nft);
        id
    }

    public fun has_basket(owner: address): bool {
        exists<GoodsBasket>(owner)
    }

    fun add_basket(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        if (!has_basket(sender_addr)) {
            let basket = GoodsBasket {
                items: Vector::empty<Goods>(),
            };
            move_to(sender, basket);
        }
    }

    public fun put_on_nft(sender: &signer, nft_id: u64, base_price: u128, add_price: u128, end_time: u64, mail: vector<u8>, original_goods_id: u128) acquires Market, GoodsNFTCapability, GoodsBasket {
        let op_nft = NFTGallery::withdraw<GoodsNFTInfo, GoodsNFTBody>(sender, nft_id);
        assert(Option::is_some(&op_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));

        let nft = Option::destroy_some(op_nft);
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));
        // add goods count
        market_info.counter = market_info.counter + 1;
        // create goods
        let nft_info = NFT::get_info<GoodsNFTInfo, GoodsNFTBody>(&nft);
        let (nft_id, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfo>(nft_info);
        type_meta.mail = mail;

        let bm = copy base_meta;
        let tm = copy type_meta;
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfo, GoodsNFTBody>(&mut cap.update_cap, &mut nft);
        let amount = body.quantity;
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = Goods{
            id: id,
            creator: owner,
            amount: amount,
            nft_id: nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidData>(),
        };
        // add basket
        add_basket(sender);
        save_goods(owner, goods);
        // deposit nft to market
        // NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(MARKET_ADDRESS, nft);
        deposit_nft(&mut market_info.nfts, nft);
        // do emit event
        Event::emit_event(&mut market_info.put_on_events, PutOnEvent{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: nft_id,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: bm,
            nft_type_meta: tm,
        });
    }

    public fun put_on(sender: &signer, title: vector<u8>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, mail: vector<u8>, original_goods_id: u128) acquires Market, GoodsBasket {
        // save counter
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        market_info.counter = market_info.counter + 1;
        let meta = NFT::new_meta_with_image(title, image, desc);
        let type_meta = GoodsNFTInfo{has_in_kind, type, resource_url, mail};
        let m2 = copy meta;
        let tm2 = copy type_meta;
        // create goods
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = Goods{
            id: id,
            creator: owner,
            amount: amount,
            nft_id: 0,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidData>(),
        };
        // add basket
        add_basket(sender);
        save_goods(owner, goods);
        // do emit event
        Event::emit_event(&mut market_info.put_on_events, PutOnEvent{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: 0,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: m2,
            nft_type_meta: tm2,
        });
    }

    public fun find_index_by_id(v: &vector<Goods>, goods_id: u128): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let goods = Vector::borrow(v, index);
            if (goods.id == goods_id) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    public fun find_nft_index_by_id(c: &vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, id: u64): Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let nft = Vector::borrow(c, idx);
            if (NFT::get_id(nft) == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    public fun find_bid_index(v: &vector<BidData>, goods_id: u128, buyer: address): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let bid = Vector::borrow(v, index);
            if (bid.goods_id == goods_id && bid.buyer == buyer) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    fun save_goods(owner: address, goods: Goods) acquires GoodsBasket{
        let basket = borrow_global_mut<GoodsBasket>(owner);
        Vector::push_back(&mut basket.items, goods);
    }

    fun get_goods(owner: address, goods_id: u128): Option<Goods> acquires GoodsBasket {
        let basket = borrow_global_mut<GoodsBasket>(owner);
        let index = find_index_by_id(&basket.items, goods_id);
        if (Option::is_some(&index)) {
            let i = Option::extract(&mut index);
            let g = Vector::remove<Goods>(&mut basket.items, i);
            Option::some(g)
        }else {
            Option::none()
        }
    }

    fun borrow_goods(list: &mut vector<Goods>, goods_id: u128): &mut Goods {
        let index = find_index_by_id(list, goods_id);
        assert(Option::is_some(&index), Errors::invalid_argument(MARKET_INVALID_INDEX));
        let i = Option::extract(&mut index);
        Vector::borrow_mut<Goods>(list, i)
    }

    fun save_bid(list: &mut vector<BidData>, bid_data: BidData) {
        Vector::push_back(list, bid_data);
    }

    fun borrow_bid_data(list: &mut vector<BidData>, index: u64): &mut BidData {
        Vector::borrow_mut<BidData>(list, index)
    }

    fun deposit_nft(list: &mut vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, nft: NFT<GoodsNFTInfo, GoodsNFTBody>) {
        Vector::push_back(list, nft);
    }

    fun withdraw_nft(list: &mut vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, nft_id: u64): Option<NFT<GoodsNFTInfo, GoodsNFTBody>> {
        let len = Vector::length(list);
        let nft = if (len == 0) {
            Option::none()
        }else {
            let idx = find_nft_index_by_id(list, nft_id);
            if (Option::is_some(&idx)) {
                let i = Option::extract(&mut idx);
                let nft = Vector::remove<NFT<GoodsNFTInfo, GoodsNFTBody>>(list, i);
                Option::some(nft)
            }else {
                Option::none()
            }
        };
        nft
    }

    fun market_pull_off(owner: address, goods_id: u128) acquires Market, GoodsBasket{
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        let g = get_goods(owner, goods_id);
        if(Option::is_some(&g)){
            let goods = Option::extract(&mut g);
            if(Vector::length(&goods.bid_list) == 0){
                let Goods{ id, creator, amount: _, nft_id, base_price: _, add_price: _, last_price: _, sell_amount: _, end_time: _, nft_base_meta: _, nft_type_meta: _, bid_list: _, original_goods_id: _ } = goods;
                if(nft_id > 0 ) {
                    let op_nft = withdraw_nft(&mut market_info.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    // deposit nft to creator
                    NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(creator, nft);
                };
                // do emit event
                Event::emit_event(&mut market_info.pull_off_events, PullOffEvent{
                    goods_id: id,
                    owner: owner,
                    nft_id: nft_id,
                });
            } else {
                save_goods(owner, goods);
            }
        }
    }

    public fun pull_off(sender: &signer, goods_id: u128) acquires Market, GoodsBasket {
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        let owner = Signer::address_of(sender);
        market_pull_off(owner, goods_id);
    }

    fun check_price(base_price: u128, add_price: u128, price: u128): bool {
        if((price - base_price) % add_price == 0 && price >= (base_price + add_price)){
            true
        }else{
            false
        }
    }

    fun sort_bid(list: &mut vector<BidData>) {
        let i = 0u64;
        let j = 0u64;
        let len = Vector::length(list);
        while(i < len){
            while(j+1 < len - i){
                let a = Vector::borrow(list, j);
                let b = Vector::borrow(list, j+1);
                if(a.price < b.price) {
                    Vector::swap(list, j, j+1);
                } else if(a.price == b.price){
                    if(a.bid_time > b.bid_time){
                        Vector::swap(list, j, j+1);
                    };
                };
                j = j + 1;
            };
            j = 0;
            i = i + 1;
        };
    }

    fun refunds_by_bid(list: &mut vector<BidData>, limit: u64, pool: &mut Token<STC>) {
        let count = 0u64;
        let valid_count = 0u64;
        let index = 0u64;
        let len = Vector::length(list);
        while(index < len) {
            let a = Vector::borrow(list, index);
            count = count + a.quantity;
            if(count > limit) {
                break
            } else if (count == limit) {
                valid_count = count;
                break
            };
            valid_count = count;
            index = index + 1;
        };
        if(count > limit && index < len) {
            let b = Vector::borrow_mut(list, index);
            b.quantity = limit - valid_count;
            let amount = (b.quantity as u128) * b.price;
            //refunds
            let tokens = Token::withdraw<STC>(pool, b.total_coin - amount);
            b.total_coin = amount;
            Account::deposit(b.buyer, tokens);
        };
        index = index + 1;
        while(len - 1 >= index ){
            let b = Vector::remove(list, len - 1);
            let tokens = Token::withdraw<STC>(pool, b.total_coin);
            Account::deposit(b.buyer, tokens);
            len = len - 1;
        };
    }

    fun get_bid_price(list: &vector<BidData>, base_price: u128, quantity: u64): u128 {
        let price = base_price;
        let len = Vector::length(list);
        let i = len;
        let count = 0u64;
        while(i > 0){
            let a = Vector::borrow(list, i - 1);
            count = count + a.quantity;
            price = a.price;
            if(count >= quantity) {
                break
            };
            i = i - 1;
        };
        price
    }

    public fun bid(sender: &signer, seller: address, goods_id: u128, price: u128, quantity: u64) acquires Market, GoodsBasket {
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        let sender_addr = Signer::address_of(sender);
        let basket = borrow_global_mut<GoodsBasket>(seller);
        let goods = borrow_goods(&mut basket.items, goods_id);
        if(goods.nft_id > 0) {
            assert(quantity == goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };
        let now = Timestamp::now_seconds();
        assert(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));
        assert(quantity > 0 && quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        let last_price = if(quantity <= goods.amount - goods.sell_amount) {
            goods.base_price
        } else {
            get_bid_price(&goods.bid_list, goods.base_price, quantity)
        };
        assert(check_price(last_price, goods.add_price, price), Errors::invalid_argument(MARKET_INVALID_PRICE));
        //accept nft
        NFTGallery::accept<GoodsNFTInfo, GoodsNFTBody>(sender);
        //save state
        let new_amount = price * (quantity as u128);
        //deduction
        let tokens = Account::withdraw<STC>(sender, new_amount);
        Token::deposit(&mut market_info.funds, tokens);
        save_bid(&mut goods.bid_list, BidData{
            buyer: sender_addr,
            goods_id,
            price,
            quantity,
            bid_count: 1,
            bid_time: now,
            total_coin: new_amount,
        });
        if(price > goods.last_price) {
            goods.last_price = price;
        };
        if(goods.sell_amount + quantity <= goods.amount) {
            goods.sell_amount = goods.sell_amount + quantity;
        }else{
            goods.sell_amount = goods.amount;
        };
        sort_bid(&mut goods.bid_list);
        let limit = goods.amount;
        refunds_by_bid(&mut goods.bid_list, limit, &mut market_info.funds);
        // do emit event
        Event::emit_event(&mut market_info.bid_events, BidEvent{
            bidder: sender_addr,
            goods_id: goods_id,
            price: price,
            quantity: quantity,
            bid_time: now,
        });
    }

    public fun set_lock(sender: &signer, is_lock: bool) acquires Market {
        check_market_owner(sender);
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        market_info.is_lock = is_lock;
    }

    public fun settlement(sender: &signer, seller: address, goods_id: u128) acquires Market, GoodsBasket, GoodsNFTCapability {
        check_market_owner(sender);
        let basket = borrow_global_mut<GoodsBasket>(seller);
        let g = borrow_goods(&mut basket.items, goods_id);
        let now = Timestamp::now_seconds();
        assert(now >= g.end_time, Errors::invalid_state(MARKET_NOT_OVER));
        let len = Vector::length(&g.bid_list);
        if(len > 0) {
            let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
            let og = get_goods(seller, goods_id);
            let goods = Option::extract(&mut og);
            let i = 0u64;
            while(i < len) {
                let nft_id = goods.nft_id;
                let bm = *&goods.nft_base_meta;
                let tm = *&goods.nft_type_meta;
                let bid_data = borrow_bid_data(&mut goods.bid_list, i);
                //mint nft
                if(nft_id > 0) {
                    let op_nft = withdraw_nft(&mut market_info.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    // deposit nft to buyer
                    NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(bid_data.buyer, nft);
                } else {
                    nft_id = mint_nft(seller, bid_data.buyer, bid_data.quantity, bm, tm);
                };
                //handling charge
                let fee = (bid_data.total_coin * MARKET_FEE_RATE) / 100;
                if(fee > 0u128) {
                    let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee);
                    Account::deposit(market_info.cashier, fee_tokens);
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin - fee);
                    Account::deposit(seller, pay_tokens);
                } else {
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin);
                    Account::deposit(seller, pay_tokens);
                };
                Event::emit_event(&mut market_info.settlement_events, SettlementEvent {
                    seller: seller,
                    buyer: bid_data.buyer,
                    goods_id: goods_id,
                    nft_id: nft_id,
                    price: bid_data.price,
                    quantity: bid_data.quantity,
                    bid_time: bid_data.bid_time,
                    time: now,
                });
                i = i + 1;
            }
        } else {
            market_pull_off(seller, goods_id);
        };
    }

    fun check_market_owner(sender: &signer): address {
        let addr = Signer::address_of(sender);
        assert(addr == MARKET_ADDRESS, Errors::invalid_argument(1000));
        addr
    }





    // ==================================================================(new version)==================================================================================

    //The action is deprecated
    const DEPRECATED_METHOD:u64 = 100;

    const MARKET_INVALID_NFT_AMOUNT: u64 = 306;
    const MARKET_INVALID_PACKAGES:u64 = 307;
    const MARKET_INVALID_SELL_WAY:u64 = 308;
    const MARKET_INVALID_BUYER:u64 = 309;

    // sell way = buy now
    const DICT_TYPE_SELL_WAY_BUY_NOW: u64 = 1801;

    // sell way = bid
    const DICT_TYPE_SELL_WAY_BID: u64 = 1802;

    // sell way = buy now + bid
    const DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID: u64 = 1803;

    // sell way = dutch
    const DICT_TYPE_SELL_WAY_DUTCH_BID: u64 = 1804;

    // gtype = goods
    const DICT_TYPE_CATEGORY_GOODS: u64 = 1901;

    // gtype = boxes
    const DICT_TYPE_CATEGORY_BOXES: u64 = 1902;

    // for test 
    const SYSTEM_ERROR_TEST:u64 = 999;

    // packages
    struct PackageV2 has copy, store, drop {
        id:u64,
        type:u64,
        preview:vector<u8>,
        resource:vector<u8>,
    }

    // item value
    struct ExtenstionV2 has copy, store, drop {
        // item
        item:u64,
        // value
        value:u128
    }

    // nft global id
    struct IdentityV2 has key, store{
        id:u64
    }

    // nft store house
    struct StorehouseV2 has key,store{
        nfts: vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>,
    }

    // trash
    struct TrashV2 has key,store{
        nfts: vector<NFT<GoodsNFTInfo, GoodsNFTBody>>,
    }

    // events
    struct EventV2<T:drop + store> has key,store{
        events: Event::EventHandle<T>,
    }

    // marketplace
    struct MarketV2 has key, store{
        counter: u64,
        is_lock: bool,
        funds: Token<STC>,
        cashier: address,
        fee_rate: u128,
        // ================================ new ========================
        // extensions
        extensions:vector<ExtenstionV2>
    }

    // not copyable
    struct GoodsNFTBodyV2 has store{
        // quantity
        quantity: u64,
    }

    // NFT ext info
    struct GoodsNFTInfoV2 has copy, store, drop {
        // has In kind
        has_in_kind: bool,
        // type
        type: u64,
        // resource url
        resource_url: vector<u8>,
        // creator email
        mail: vector<u8>,
        // ================================ new ========================
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // the mystery box or goods always false, but its true when box opened
        is_open: bool,
        // main nft id
        main_nft_id:u64,
        // tags
        tags:vector<u8>,
        // boxes
        packages:vector<PackageV2>,
        // extensions
        extensions:vector<ExtenstionV2>
    }

    // goods info
    struct GoodsV2 has store, drop{
        id: u128,
        //creator
        creator: address,
        //amount of put on
        amount: u64,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //last price
        last_price: u128,
        //sell amount
        sell_amount: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfoV2,
        bid_list: vector<BidDataV2>,
        // ================================ new ========================
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // duration time
        duration:u64,
        // start time
        start_time: u64,
        // fixed_price
        fixed_price:u128,
        // dutch auction start price
        dutch_start_price:u128,
        // dutch auction end price
        dutch_end_price:u128,
        // original_amount
        original_amount:u64,
        // extensions
        extensions:vector<ExtenstionV2>
    }

    struct BidDataV2 has copy, store, drop {
        buyer: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_count: u64,
        bid_time: u64,
        total_coin: u128,
    }

    //goods basket
    struct GoodsBasketV2 has key, store{
        items: vector<GoodsV2>,
    }

    struct GoodsNFTNewCapabilityV2 has key {
        mint_cap: MintCapability<GoodsNFTInfoV2>,
        burn_cap: BurnCapability<GoodsNFTInfoV2>,
        update_cap: UpdateCapability<GoodsNFTInfoV2>,
        old_burn_cap: BurnCapability<GoodsNFTInfo>,
    }

    struct UpgradeNFTEventV2 has drop,store{
        goods_id:u128,
        main_nft_id:u64,// new goods 1000+, old one is the same of old_nft_id
        old_version:u64,
        old_nft_id:u64,
        new_version:u64,
        new_nft_id:u64,
    }

    // open box event
    struct OpenBoxEventv2 has drop,store{
        parent_main_nft_id:u64,
        main_nft_id:u64,
        new_nft_id:u64,
        new_version:u64,
        preview_url:vector<u8>,
        //======================== new ======================
        unopen:u64,
        time:u64,
        is_open:bool,
        resource_url:vector<u8>
    }

    struct BuyNowEventV2 has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        time: u64,
        //======================== new ======================
        // nft main id
        main_nft_id:u64,
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // remain amount
        remain_amount:u64,
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // is_open
        is_open:bool
    }

    //put on event
    struct PutOnEventV2 has drop, store {
        goods_id: u128,
        //seller
        owner: address,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //total amount
        amount: u64,
        // puton time
        put_on_time: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfoV2,
        //================================================ new ======================
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // duration time
        duration:u64,
        // start time
        start_time: u64,
        // fixed_price
        fixed_price:u128,
        // dutch auction start price
        dutch_start_price:u128,
        // dutch auction end price
        dutch_end_price:u128,
        // original_amount
        original_amount:u64,
        // extensions
        extensions:vector<ExtenstionV2>

    }

    //pull off event
    struct PullOffEventV2 has drop, store {
        owner: address,
        goods_id: u128,
        nft_id: u64,
    }

    struct BidEventV2 has drop, store {
        bidder: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_time: u64,
    }

    struct SettlementEventV2 has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        bid_time: u64,
        time: u64,
        //======================== new ======================
        // nft main id
        main_nft_id:u64,
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // is open
        is_open:bool
    }


    public fun create_test_data_v2(sender: &signer) acquires IdentityV2,GoodsNFTCapability,GoodsNFTNewCapabilityV2 {

        check_market_owner(sender);
        
        let sender_addr = Signer::address_of(sender);

        // create old nft
         NFTGallery::accept<GoodsNFTInfo, GoodsNFTBody>(sender);
        let old_cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let old_meta = NFT::new_meta_with_image(b"cyberrare", b"https://ichess.fun/avatar.jpg", b"cyberrare is a great NFT marketplace");
        let old_type_meta = GoodsNFTInfo{ has_in_kind:false , type:0u64, resource_url:b"https://ichess.fun/avatar.jpg", mail:b"support@cyberrare.io"};
        let old_nft = NFT::mint_with_cap<GoodsNFTInfo, GoodsNFTBody, GoodsNFTInfo>(sender_addr, &mut old_cap.mint_cap, old_meta, old_type_meta, GoodsNFTBody{quantity:1});
        NFTGallery::deposit_to(sender_addr, old_nft);

        // create new nft
        let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
        identity.id = identity.id + 1;
         NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_meta = NFT::new_meta_with_image(b"cyberrare", b"https://ichess.fun/avatar.jpg", b"cyberrare is a great NFT marketplace");
        let new_type_meta = GoodsNFTInfoV2{ has_in_kind:false , type:0u64, resource_url:b"https://ichess.fun/avatar.jpg", mail:b"support@cyberrare.io",gtype:DICT_TYPE_CATEGORY_GOODS,is_open:false,main_nft_id:identity.id,tags:Vector::empty<u8>(),packages:Vector::empty<PackageV2>(),extensions:Vector::empty<ExtenstionV2>()};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(sender_addr, &mut new_cap.mint_cap, new_meta, new_type_meta, GoodsNFTBodyV2{quantity:1});
        NFTGallery::deposit_to(sender_addr, new_nft);
    }

    fun get_packages_v2(packages: vector<vector<u8>>,package_types:vector<u64>):vector<PackageV2> {
        let len = Vector::length(&packages);
        let new_packages = Vector::empty<PackageV2>();
        let i = 0u64;
        while(i < len){
            let package = *Vector::borrow(&packages,i);
            let package_type = *Vector::borrow(&package_types,i);
            Vector::push_back<PackageV2>(&mut new_packages, PackageV2{id:(i+1), type:package_type, preview:Vector::empty<u8>(),resource: package });
            i=i+1;
        };
        new_packages
    }

    fun save_goods_v2(owner: address, goods: GoodsV2) acquires GoodsBasketV2{
        let basket = borrow_global_mut<GoodsBasketV2>(owner);
        Vector::push_back(&mut basket.items, goods);
    }

    fun add_basket_v2(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        if (!exists<GoodsBasketV2>(sender_addr)) {
            let basket = GoodsBasketV2 {
                items: Vector::empty<GoodsV2>(),
            };
            move_to(sender, basket);
        }
    }

    fun mint_nft_v2(creator: address, receiver: address, quantity: u64, base_meta: Metadata, type_meta: GoodsNFTInfoV2): u64 acquires GoodsNFTNewCapabilityV2 {
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let tm = copy type_meta;
        let md = copy base_meta;
        let nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(creator, &mut cap.mint_cap, md, tm, GoodsNFTBodyV2{quantity});
        let id = NFT::get_id(&nft);
        NFTGallery::deposit_to(receiver, nft);
        id
    }

    fun deposit_nft_v2(list: &mut vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, nft: NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>) {
        Vector::push_back(list, nft);
    }

    fun deposit_trush_v2(list: &mut vector<NFT<GoodsNFTInfo,GoodsNFTBody>>, nft: NFT<GoodsNFTInfo, GoodsNFTBody>){
        Vector::push_back(list, nft);
    }

    public fun find_index_by_id_v2(v: &vector<GoodsV2>, goods_id: u128): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let goods = Vector::borrow(v, index);
            if (goods.id == goods_id) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    fun borrow_goods_v2(list: &mut vector<GoodsV2>, goods_id: u128): &mut GoodsV2 {
        let index = find_index_by_id_v2(list, goods_id);
        assert(Option::is_some(&index), Errors::invalid_argument(MARKET_INVALID_INDEX));
        let i = Option::extract(&mut index);
        Vector::borrow_mut<GoodsV2>(list, i)
    }

    fun get_bid_price_v2(list: &vector<BidDataV2>, base_price: u128, quantity: u64): u128 {
        let price = base_price;
        let len = Vector::length(list);
        let i = len;
        let count = 0u64;
        while(i > 0){
            let a = Vector::borrow(list, i - 1);
            count = count + a.quantity;
            price = a.price;
            if(count >= quantity) {
                break
            };
            i = i - 1;
        };
        price
    }

    fun save_bid_v2(list: &mut vector<BidDataV2>, bid_data: BidDataV2) {
        Vector::push_back(list, bid_data);
    }

    fun sort_bid_v2(list: &mut vector<BidDataV2>) {
        let i = 0u64;
        let j = 0u64;
        let len = Vector::length(list);
        while(i < len){
            while(j+1 < len - i){
                let a = Vector::borrow(list, j);
                let b = Vector::borrow(list, j+1);
                if(a.price < b.price) {
                    Vector::swap(list, j, j+1);
                } else if(a.price == b.price){
                    if(a.bid_time > b.bid_time){
                        Vector::swap(list, j, j+1);
                    };
                };
                j = j + 1;
            };
            j = 0;
            i = i + 1;
        };
    }

    fun refunds_by_bid_v2(list: &mut vector<BidDataV2>, limit: u64, pool: &mut Token<STC>) {
        let count = 0u64;
        let valid_count = 0u64;
        let index = 0u64;
        let len = Vector::length(list);
        while(index < len) {
            let a = Vector::borrow(list, index);
            count = count + a.quantity;
            if(count > limit) {
                break
            } else if (count == limit) {
                valid_count = count;
                break
            };
            valid_count = count;
            index = index + 1;
        };
        if(count > limit && index < len) {
            let b = Vector::borrow_mut(list, index);
            b.quantity = limit - valid_count;
            let amount = (b.quantity as u128) * b.price;
            //refunds
            let tokens = Token::withdraw<STC>(pool, b.total_coin - amount);
            b.total_coin = amount;
            Account::deposit(b.buyer, tokens);
        };
        index = index + 1;
        while(len - 1 >= index ){
            let b = Vector::remove(list, len - 1);
            let tokens = Token::withdraw<STC>(pool, b.total_coin);
            Account::deposit(b.buyer, tokens);
            len = len - 1;
        };
    }

    fun get_goods_v2(owner: address, goods_id: u128): Option<GoodsV2> acquires GoodsBasketV2 {
        let basket = borrow_global_mut<GoodsBasketV2>(owner);
        let index = find_index_by_id_v2(&basket.items, goods_id);
        if (Option::is_some(&index)) {
            let i = Option::extract(&mut index);
            let g = Vector::remove<GoodsV2>(&mut basket.items, i);
            Option::some(g)
        }else {
            Option::none()
        }
    }


    fun borrow_bid_data_v2(list: &mut vector<BidDataV2>, index: u64): &mut BidDataV2 {
        Vector::borrow_mut<BidDataV2>(list, index)
    }


    fun withdraw_nft_v2(list: &mut vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, nft_id: u64): Option<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>> {
        let len = Vector::length(list);
        let nft = if (len == 0) {
            Option::none()
        }else {
            let idx = find_nft_index_by_id_v2(list, nft_id);
            if (Option::is_some(&idx)) {
                let i = Option::extract(&mut idx);
                let nft = Vector::remove<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>(list, i);
                Option::some(nft)
            }else {
                Option::none()
            }
        };
        nft
    }

    public fun find_nft_index_by_id_v2(c: &vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, id: u64): Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let nft = Vector::borrow(c, idx);
            if (NFT::get_id(nft) == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    fun market_pull_off_v2(owner: address, goods_id: u128) acquires EventV2,StorehouseV2, GoodsBasketV2{
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        let g = get_goods_v2(owner, goods_id);
        if(Option::is_some(&g)){
            let goods = Option::extract(&mut g);
            if(Vector::length(&goods.bid_list) == 0){

                let GoodsV2{ id, creator, amount: _, nft_id, base_price: _, add_price: _, last_price: _, sell_amount: _, end_time: _, nft_base_meta: _, nft_type_meta: _, bid_list: _, original_goods_id: _,sell_way:_,duration:_,start_time:_,fixed_price:_,dutch_start_price:_,dutch_end_price:_,extensions:_,original_amount:_ } = goods;
                if(nft_id > 0 ) {
                    let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    // deposit nft to creator
                    NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(creator, nft);
                };
                // do emit event
                let pull_off_event = borrow_global_mut<EventV2<PullOffEventV2>>(MARKET_ADDRESS);
                Event::emit_event(&mut pull_off_event.events, PullOffEventV2{
                    goods_id: id,
                    owner: owner,
                    nft_id: nft_id,
                });
            } else {
                save_goods_v2(owner, goods);
            }
        }
    }

    public fun pull_off_v2(sender: &signer, goods_id: u128) acquires EventV2,MarketV2,StorehouseV2, GoodsBasketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        
        let owner = Signer::address_of(sender);
        market_pull_off_v2(owner, goods_id);
    }

    fun put_on_nft_new_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2 {
        
        // get nft info
        let new_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);    
        assert(Option::is_some(&new_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));    

        let nft = Option::destroy_some(new_nft);
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&nft);
        let (nft_id, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(nft_info);
        type_meta.tags = tags;
        NFT::update_meta_with_cap(&mut cap.update_cap, &mut nft,copy base_meta,copy type_meta);

        // add goods count        
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.counter = market_info.counter + 1;

        // create goods
        let bm = copy base_meta;
        let tm = copy type_meta;
        let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2>(&mut cap.update_cap, &mut nft);
        let amount = if(type_meta.gtype==DICT_TYPE_CATEGORY_BOXES){
            Vector::length(&type_meta.packages)
        }else{
            body.quantity
        };
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = GoodsV2 {
            id: id,
            creator: owner,
            amount: amount,
            nft_id: nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // deposit nft to market
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        deposit_nft_v2(&mut storehouse.nfts, nft);

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: nft_id,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: bm,
            nft_type_meta: tm,

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    fun put_on_nft_old_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2,GoodsNFTCapability {

        // get old nft 
        let owner = Signer::address_of(sender);
        let get_old_nft = NFTGallery::withdraw<GoodsNFTInfo, GoodsNFTBody>(sender, nft_id);
        assert(Option::is_some(&get_old_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));  

        let old_cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let old_nft = Option::destroy_some(get_old_nft);
        let old_nft_info = NFT::get_info<GoodsNFTInfo, GoodsNFTBody>(&old_nft);
        let (_old_nft_id, _, old_base_meta, old_type_meta) = NFT::unpack_info<GoodsNFTInfo>(old_nft_info);
        let old_nft_body = NFT::borrow_body_mut_with_cap<GoodsNFTInfo, GoodsNFTBody>(&mut old_cap.update_cap, &mut old_nft);
        //let old_trush = borrow_global_mut<TrashV2>(MARKET_ADDRESS);
        
        // create new nft
        let new_amount = old_nft_body.quantity;
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_base_meta = copy old_base_meta;
        let new_type_meta = GoodsNFTInfoV2{has_in_kind:*&old_type_meta.has_in_kind, type:*&old_type_meta.type, resource_url:*&old_type_meta.resource_url, mail:Vector::empty<u8>(), gtype:DICT_TYPE_CATEGORY_GOODS, is_open:false, main_nft_id:nft_id,tags, packages:Vector::empty<PackageV2>() ,extensions:Vector::empty<ExtenstionV2>()};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(owner, &mut new_cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:new_amount});
        let new_nft_id = NFT::get_id(&new_nft);

        // burn old nft
        //deposit_trush_v2(&mut old_trush.nfts,old_nft);
        let GoodsNFTBody{ quantity:_ } = NFT::burn_with_cap(&mut new_cap.old_burn_cap,old_nft);

        // add goods count        
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.counter = market_info.counter + 1;

        // create goods
        let bm = copy new_base_meta;
        let tm = copy new_type_meta;
        //let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2>(&mut new_cap.update_cap, &mut new_nft);
        
        let id = (market_info.counter as u128);
        let goods = GoodsV2 {
            id: id,
            creator: owner,
            amount: new_amount,
            nft_id: new_nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: new_base_meta,
            nft_type_meta: new_type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:new_amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // deposit nft to market
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        deposit_nft_v2(&mut storehouse.nfts, new_nft);

        let upgrade_nft_event = borrow_global_mut<EventV2<UpgradeNFTEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut upgrade_nft_event.events, UpgradeNFTEventV2{
            goods_id:id,
            main_nft_id:nft_id,
            old_version:1,
            old_nft_id:nft_id,
            new_version:2,
            new_nft_id:new_nft_id,
        });

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: new_nft_id,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: new_amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: bm,
            nft_type_meta: tm,

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:new_amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    // cancel goods
    public fun cancel_goods_v2(sender: &signer,seller:address, goods_id: u128) acquires Market, GoodsBasket{

        check_market_owner(sender);

        market_pull_off(seller, goods_id);
    }

    // sync market 
    public fun sync_market_v2(sender: &signer) acquires Market,MarketV2{

        check_market_owner(sender);

        // sync market
        let old_market = borrow_global_mut<Market>(MARKET_ADDRESS);
        let new_market = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        new_market.cashier = old_market.cashier;
        new_market.fee_rate = old_market.fee_rate;

        let market_funds = Token::value(&old_market.funds);
        if(market_funds>0){
            let tokens = Token::withdraw<STC>(&mut old_market.funds, market_funds);
            Token::deposit(&mut new_market.funds, tokens); 
        }
    }

    // init market
    public fun init_market_v2(sender: &signer, cashier: address, title: vector<u8>, desc: vector<u8>, image: vector<u8>)  {       

        check_market_owner(sender);

        let meta = NFT::new_meta_with_image(title, image, desc);
        NFT::register_v2<GoodsNFTInfoV2>(sender, meta);

        // init new capability
        let new_mint_cap = NFT::remove_mint_capability<GoodsNFTInfoV2>(sender);
        let new_burn_cap = NFT::remove_burn_capability<GoodsNFTInfoV2>(sender);
        let new_update_cap = NFT::remove_update_capability<GoodsNFTInfoV2>(sender);
        let old_burn_cap = NFT::remove_burn_capability<GoodsNFTInfo>(sender);
        move_to(sender, GoodsNFTNewCapabilityV2{mint_cap:new_mint_cap, burn_cap:new_burn_cap, update_cap:new_update_cap,old_burn_cap:old_burn_cap});

        // init identity
        move_to<IdentityV2>(sender,IdentityV2{
            id:10000
        });

        // init store house
        move_to<StorehouseV2>(sender,StorehouseV2{
            nfts:Vector::empty<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>()
        });

        move_to<EventV2<BuyNowEventV2>>(sender,EventV2<BuyNowEventV2>{
            events:Event::new_event_handle<BuyNowEventV2>(sender),
        });

        // init open box event
        move_to<EventV2<OpenBoxEventv2>>(sender,EventV2<OpenBoxEventv2>{
            events:Event::new_event_handle<OpenBoxEventv2>(sender),
        });

        move_to<EventV2<UpgradeNFTEventV2>>(sender,EventV2<UpgradeNFTEventV2>{
            events:Event::new_event_handle<UpgradeNFTEventV2>(sender),
        });

        // init put on event
        move_to<EventV2<PutOnEventV2>>(sender,EventV2<PutOnEventV2>{
            events:Event::new_event_handle<PutOnEventV2>(sender),
        });
        
        // init pull off event
        move_to<EventV2<PullOffEventV2>>(sender,EventV2<PullOffEventV2>{
            events:Event::new_event_handle<PullOffEventV2>(sender),
        });

        // init bid event
        move_to<EventV2<BidEventV2>>(sender,EventV2<BidEventV2>{
            events:Event::new_event_handle<BidEventV2>(sender),
        });

        // init settlement event
        move_to<EventV2<SettlementEventV2>>(sender,EventV2<SettlementEventV2>{
            events:Event::new_event_handle<SettlementEventV2>(sender),
        });
        
        // init market
        move_to<MarketV2>(sender, MarketV2{
            counter: 10000,
            is_lock: false,
            funds: Token::zero<STC>(),
            cashier: cashier,
            fee_rate: MARKET_FEE_RATE,
            extensions:Vector::empty<ExtenstionV2>()
        });


    }

    // update nft meta
    public fun update_meta_v2(sender: &signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>) acquires GoodsNFTCapability {
        check_market_owner(sender); // check authorize
        let meta = NFT::new_meta_with_image(title, image, desc);// new a meta
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);// borrow cap
        NFT::update_nft_type_info_meta_with_cap<GoodsNFTInfo>(&mut cap.update_cap, meta); // change nft meta info
    }

    // put a new nft on market
    public fun put_on_v2(sender: &signer, title: vector<u8>, sell_way:u64, fixed_price:u128, gtype:u64, tags:vector<u8>, packages:vector<vector<u8>>,package_types:vector<u64>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, original_goods_id: u128) acquires MarketV2,GoodsBasketV2,EventV2 {
        
        // verify info
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let package_count = Vector::length(&packages);
        let package_type_count = Vector::length(&package_types);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));
        assert(amount>0 && amount <= ARG_MAX_BID, Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));

        // the amount must be equal package_count when boxes
        if(gtype == DICT_TYPE_CATEGORY_BOXES){
            assert(package_count==package_type_count,Errors::invalid_argument(MARKET_INVALID_PACKAGES));
            assert(amount == package_count, Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));
        }else{
            assert(package_count==0 && package_type_count==0,Errors::invalid_argument(MARKET_INVALID_PACKAGES));
        };

        if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){
            assert(fixed_price>0 && base_price==0 && add_price==0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BID){
            assert(fixed_price==0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){
            assert(fixed_price>0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
            assert(fixed_price>base_price,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else{
            assert(false,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        };

        market_info.counter = market_info.counter + 1;

        // create goods
        let new_packages = get_packages_v2(packages,package_types);
        let base_meta = NFT::new_meta_with_image(title, image, desc);
        let type_meta = GoodsNFTInfoV2{has_in_kind, type, resource_url, mail:Vector::empty<u8>(), gtype, is_open:false, main_nft_id:0,tags, packages:new_packages ,extensions:Vector::empty<ExtenstionV2>()};
        let m2 = copy base_meta;
        let tm2 = copy type_meta;
        // create goods
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = GoodsV2{
            id: id,
            creator: owner,
            amount: amount,
            nft_id: 0,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2 {
            goods_id: id,
            //seller
            owner: owner,
            nft_id: 0,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: m2,
            nft_type_meta: tm2,

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    // put a exist nft on  market 
    public fun put_on_nft_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, version:u64, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2,GoodsNFTCapability{
        
        // check lock
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);

        // check sell way
        if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){
            assert(fixed_price>0 && base_price==0 && add_price==0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BID){
            assert(fixed_price==0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){
            assert(fixed_price>0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
            assert(fixed_price>base_price,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else{
            assert(false,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        };

        if(version==1){
            put_on_nft_old_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        }else if(version==2){
            put_on_nft_new_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        }else{
            assert(false, Errors::invalid_argument(MARKET_INVALID_NFT_ID));
        }

        // exchange nft
        // let sender_addr = Signer::address_of(sender);
        // let new_nft_info = NFTGallery::get_nft_info_by_id<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr,nft_id);
        // let old_nft_info = NFTGallery::get_nft_info_by_id<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr,nft_id);
        // if(Option::is_some(&old_nft_info)){
        //     put_on_nft_old_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        // }else if(Option::is_some(&new_nft_info)){
        //     put_on_nft_new_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        // }else {
        //     assert(false, Errors::invalid_argument(MARKET_INVALID_NFT_ID));
        // }

    }

    fun get_hex_vector(number:u8):vector<u8>{
        let data = Vector::empty<u8>();
        while(number!=0) {
            let temp = number % 16;
            if( temp < 10){
                temp = temp + 48;
            }else{
                temp = temp + 55;
            };
            Vector::push_back(&mut data,temp);
            number = number / 16;
        };
        data
    }

    // open mystery box
    public fun open_box_v2(sender: &signer, nft_id: u64, quantity: u64) acquires EventV2,MarketV2,IdentityV2,GoodsNFTNewCapabilityV2{

        // check lock      
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // check nft
        let sender_addr = Signer::address_of(sender);
        let new_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);
        assert(Option::is_some(&new_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));

        // check quantity 
        let nft = Option::destroy_some(new_nft);
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&nft);
        let (_, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(nft_info);
        let count = Vector::length(&type_meta.packages);
        assert(count>0 && quantity>0 && quantity<=count,Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));

        // open boxes
        let now = Timestamp::now_milliseconds();
        let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
        let i = 0u64;
        while(i < quantity){
            let random = now + i + 100 * i;
            let index = random % (count-i); 
            let item = Vector::remove<PackageV2>(&mut type_meta.packages, index);

            // generate name
            let data = get_hex_vector((item.id as u8));
            let name = Vector::empty<u8>();
            Vector::append(&mut name,NFT::meta_name(&base_meta));
            Vector::append(&mut name,(b" #"));
            Vector::append(&mut name,data);
            
            // use the box resource to create new nft
            let preview_url = if(item.type == 0){
                *&item.resource
            }else{
                NFT::meta_image(&base_meta)
            };
            let resource_url = *&item.resource;
            identity.id = identity.id +1;
            let new_base_meta = NFT::new_meta_with_image(*&name, copy preview_url, NFT::meta_description(&base_meta));
            let new_type_meta = GoodsNFTInfoV2{ has_in_kind:*&type_meta.has_in_kind, type:*&type_meta.type, resource_url:*&item.resource, mail:Vector::empty<u8>(), gtype:DICT_TYPE_CATEGORY_GOODS, is_open:true, main_nft_id:identity.id,tags:*&type_meta.tags, packages:Vector::empty<PackageV2>() ,extensions:Vector::empty<ExtenstionV2>() };
            let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(MARKET_ADDRESS, &mut cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:1});
            let new_nft_id = NFT::get_id(&new_nft);

            // deposit new nft to user
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr, new_nft);

            // do emit event
            let open_box_event = borrow_global_mut<EventV2<OpenBoxEventv2>>(MARKET_ADDRESS);
            Event::emit_event(&mut open_box_event.events, OpenBoxEventv2 {
                parent_main_nft_id:*&type_meta.main_nft_id,
                main_nft_id:identity.id,
                new_nft_id:new_nft_id,
                new_version:2,
                preview_url:preview_url,
                resource_url:resource_url,
                unopen:count-quantity,
                time:now,
                is_open:true
            });

            i = i+1;
        };

        // burn nft
        if(count==quantity){
            let GoodsNFTBodyV2{ quantity:_ } = NFT::burn_with_cap(&mut cap.burn_cap,nft);
        }else{
            NFT::update_meta_with_cap(&mut cap.update_cap, &mut nft,copy base_meta,copy type_meta);
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr, nft);
        };
    }

    // bid goods
    public fun bid_v2(sender: &signer, seller: address, goods_id: u128, price: u128, quantity: u64) acquires EventV2, MarketV2, GoodsBasketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // check owner
        let sender_addr = Signer::address_of(sender);
        assert(sender_addr!=seller, Errors::invalid_argument(MARKET_INVALID_BUYER));
        
        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let goods = borrow_goods_v2(&mut basket.items, goods_id);
        if(goods.nft_id > 0) {
            assert(quantity == goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };

        assert(goods.sell_way==DICT_TYPE_SELL_WAY_BID || goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        
        let now = Timestamp::now_seconds();
        assert(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));
        assert(quantity > 0 && quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        let last_price = if(quantity <= goods.amount - goods.sell_amount) {
            goods.base_price
        } else {
            get_bid_price_v2(&goods.bid_list, goods.base_price, quantity)
        };
        assert(check_price(last_price, goods.add_price, price), Errors::invalid_argument(MARKET_INVALID_PRICE));
        //accept nft
        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        //save state
        let new_amount = price * (quantity as u128);
        //deduction
        let tokens = Account::withdraw<STC>(sender, new_amount);
        Token::deposit(&mut market_info.funds, tokens);
        save_bid_v2(&mut goods.bid_list, BidDataV2{
            buyer: sender_addr,
            goods_id,
            price,
            quantity,
            bid_count: 1,
            bid_time: now,
            total_coin: new_amount,
        });
        if(price > goods.last_price) {
            goods.last_price = price;
        };
        if(goods.sell_amount + quantity <= goods.amount) {
            goods.sell_amount = goods.sell_amount + quantity;
        }else{
            goods.sell_amount = goods.amount;
        };
        sort_bid_v2(&mut goods.bid_list);
        let limit = goods.amount;
        refunds_by_bid_v2(&mut goods.bid_list, limit, &mut market_info.funds);

        // do emit event
        let bid_event = borrow_global_mut<EventV2<BidEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut bid_event.events, BidEventV2{
            bidder: sender_addr,
            goods_id: goods_id,
            price: price,
            quantity: quantity,
            bid_time: now,
        });
    }

    // buy now 
    public fun buy_now_v2(sender: &signer, seller: address, goods_id: u128, quantity: u64) acquires EventV2,MarketV2,IdentityV2,StorehouseV2, GoodsBasketV2,GoodsNFTNewCapabilityV2 {//EventV2, 

        let now = Timestamp::now_seconds();
        let buyer = Signer::address_of(sender);

        // check owner
        assert(buyer!=seller, Errors::invalid_argument(MARKET_INVALID_BUYER));

        // check lock
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // get goods
        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let goods = borrow_goods_v2(&mut basket.items, goods_id);

        // check buy all nft if the nft is minted
        if(goods.nft_id > 0) {
            assert(quantity == goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };

        // check sell way
        assert(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW || goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));

        // accept nft
        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);

        // transfer tokens to market
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let fixed_price = goods.fixed_price;
        let token_amount = fixed_price * (quantity as u128);
        let tokens = Account::withdraw<STC>(sender, token_amount);
        Token::deposit(&mut market_info.funds, tokens);

        let is_remove = false;
        if(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){

            // check quantity
            assert(quantity > 0 && goods.sell_amount + quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));

            // update goods amount
            goods.sell_amount = goods.sell_amount + quantity;

            if(goods.sell_amount==goods.amount){
                is_remove=true;
            }

        }else if(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){

            // check quantity
            assert(quantity > 0 && quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));

            // check end time
            assert(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));

            // calculate amount
            goods.amount = goods.amount - quantity;
            if(goods.sell_amount + quantity <= goods.amount) {
                goods.sell_amount = goods.sell_amount + quantity;
            }else{
                goods.sell_amount = goods.amount;
            };


            //assert(quantity==0,Errors::invalid_argument(SYSTEM_ERROR_TEST));

            // refund bid list
            let limit = goods.amount;
            let len = Vector::length(&goods.bid_list);
            if(len>0){
                refunds_by_bid_v2(&mut goods.bid_list, limit, &mut market_info.funds);
            };

            if(limit==0){
                is_remove=true;
            }
        };


        // buy nft
        let nft_id = goods.nft_id;
        let sell_way = goods.sell_way;
        let remain_amount = goods.amount;
        let bm = *&goods.nft_base_meta;
        let tm = *&goods.nft_type_meta;
        let main_nft_id = tm.main_nft_id;
        let gtype = tm.gtype;
        let is_open = tm.is_open;

        if(nft_id > 0) {
            // transfer nft to buyer
            let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
            let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
            let nft = Option::destroy_some(op_nft);
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(buyer, nft);

        } else {
            // get ramdom resource if boxes
            if(tm.gtype==DICT_TYPE_CATEGORY_BOXES){
                let packages = get_random_package(&mut goods.nft_type_meta.packages,quantity);
                tm.packages = packages;
            };

            // mint nft to buyer
            let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
            identity.id = identity.id +1;
            tm.main_nft_id = identity.id;
            main_nft_id = identity.id;
            nft_id = mint_nft_v2(seller, buyer, quantity, bm, tm);
        };

        //handling charge
        let fee = (token_amount * MARKET_FEE_RATE) / 100;
        if(fee > 0u128) {
            let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee);
            Account::deposit(market_info.cashier, fee_tokens);
            //to pay
            let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, token_amount - fee);
            Account::deposit(seller, pay_tokens);
        } else {
            //to pay
            let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, token_amount);
            Account::deposit(seller, pay_tokens);
        };

        // delete goods info
        if(is_remove==true){
            let get_remove_goods = get_goods_v2(seller, goods_id);
            let _ = Option::extract(&mut get_remove_goods);
        };

        // do emit event
        let buy_now_event = borrow_global_mut<EventV2<BuyNowEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut buy_now_event.events, BuyNowEventV2 {
            seller: seller,
            buyer:buyer,
            goods_id: goods_id,
            nft_id: nft_id,
            price: fixed_price,
            quantity: quantity,
            time: now,
            main_nft_id:main_nft_id,
            sell_way:sell_way,
            remain_amount:remain_amount,
            gtype:gtype,
            is_open:is_open
        });

    }

    fun get_random_package(packages:&mut vector<PackageV2>,quantity:u64): vector<PackageV2>{
        let new_packages = Vector::empty<PackageV2>();
        let count = Vector::length(packages);
        let i=0u64;
        let now = Timestamp::now_milliseconds();
        while(i < quantity){
            let random = now + i + 100 * i;
            let index = random % (count - i);
            let package = Vector::remove<PackageV2>(packages, index);
            Vector::push_back<PackageV2>(&mut new_packages,*&package);
            i = i + 1;
        };
        new_packages
    }

    // settlement
    public fun settlement_v2(sender: &signer, seller: address, goods_id: u128) acquires EventV2,MarketV2,IdentityV2,StorehouseV2, GoodsBasketV2, GoodsNFTNewCapabilityV2 {
        check_market_owner(sender);

        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let g = borrow_goods_v2(&mut basket.items, goods_id);
        let now = Timestamp::now_seconds();
        assert(now >= g.end_time, Errors::invalid_state(MARKET_NOT_OVER));
        let len = Vector::length(&g.bid_list);
        if(len > 0) {
            let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
            let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
            let og = get_goods_v2(seller, goods_id);
            let goods = Option::extract(&mut og);
            let pkg = *&goods.nft_type_meta.packages;
            let i = 0u64;
            while(i < len) {
                let nft_id = goods.nft_id;
                let bm = *&goods.nft_base_meta;
                let tm = *&goods.nft_type_meta;
                let gtype = tm.gtype;
                let is_open = tm.is_open;
                let main_nft_id = tm.main_nft_id;
                let bid_data = borrow_bid_data_v2(&mut goods.bid_list, i);
                if(nft_id > 0) {
                    // transfer nft to buyer
                    let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(bid_data.buyer, nft);

                } else {
                    // get ramdom resource if boxes
                    if(tm.gtype==DICT_TYPE_CATEGORY_BOXES){
                        let packages = get_random_package(&mut pkg,bid_data.quantity);
                        tm.packages = packages;
                    };

                    // mint nft to buyer
                    let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
                    identity.id = identity.id +1;
                    tm.main_nft_id = identity.id;
                    main_nft_id = identity.id;
                    nft_id = mint_nft_v2(seller, bid_data.buyer, bid_data.quantity, bm, tm);
                };

                //handling charge
                let fee = (bid_data.total_coin * MARKET_FEE_RATE) / 100;
                if(fee > 0u128) {
                    let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee);
                    Account::deposit(market_info.cashier, fee_tokens);
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin - fee);
                    Account::deposit(seller, pay_tokens);
                } else {
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin);
                    Account::deposit(seller, pay_tokens);
                };

                // do emit event
                let settlement_event = borrow_global_mut<EventV2<SettlementEventV2>>(MARKET_ADDRESS);
                Event::emit_event(&mut settlement_event.events, SettlementEventV2 {
                    seller: seller,
                    buyer: bid_data.buyer,
                    goods_id: goods_id,
                    nft_id: nft_id,
                    price: bid_data.price,
                    quantity: bid_data.quantity,
                    bid_time: bid_data.bid_time,
                    time: now,
                    main_nft_id:main_nft_id,
                    sell_way:goods.sell_way,
                    gtype:gtype,
                    is_open:is_open
                });
                i = i + 1;
            }
        } else {
            market_pull_off_v2(seller, goods_id);
        };
    }

    // lock market
    public fun set_lock_v2(sender: &signer, is_lock: bool) acquires MarketV2 {
        check_market_owner(sender);
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.is_lock = is_lock;
    }






}

module MarketScript {
    use 0x1e0c830eF929e530DDcfA8d79f758d09::Market;

    //account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::init_market --arg 0x1e0c830eF929e530DDcfA8d79f758d09
    public(script) fun init_market(account: signer, cashier: address) {
        Market::init(&account, cashier);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::put_on --arg <...>
    public(script) fun put_on(account: signer, title: vector<u8>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on(&account, title, type, base_price, add_price, image, resource_url, desc, has_in_kind, end_time, amount, mail, original_goods_id);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::put_on_nft --arg <...>
    public(script) fun put_on_nft(sender: signer, nft_id: u64, base_price: u128, add_price: u128, end_time: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on_nft(&sender, nft_id, base_price, add_price, end_time, mail, original_goods_id);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::pull_off --arg <...>
    public(script) fun pull_off(account: signer, goods_id: u128) {
        Market::pull_off(&account, goods_id);
    }

    // account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::bid --arg 0x1e0c830eF929e530DDcfA8d79f758d09 1u128 12u128 1u64
    // "gas_used": "344104"
    public(script) fun bid(account: signer, seller: address, goods_id: u128, price: u128, quantity: u64) {
        Market::bid(&account, seller, goods_id, price, quantity);
    }

    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::settlement --arg 0x1e0c830eF929e530DDcfA8d79f758d09 1u128
    public(script) fun settlement(sender: signer, seller: address, goods_id: u128) {
        Market::settlement(&sender, seller, goods_id);
    }

    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::set_lock --arg false
    public(script) fun set_lock(sender: signer, is_lock: bool) {
        Market::set_lock(&sender, is_lock);
    }

    public(script) fun upgrade(sender: signer) {
        Market::upgrade(&sender);
    }


    // ================================================================================(new version)=========================================================================================================

    //account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::init_market_v2 --arg <...>
    public(script) fun init_market_v2(sender: signer, cashier: address, title: vector<u8>, desc: vector<u8>, image: vector<u8>) {
        Market::init_market_v2(&sender, cashier, title, desc, image);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::put_on_v2 --arg <...>
    public(script) fun put_on_v2(sender: signer, title: vector<u8>, sell_way:u64, fixed_price:u128, gtype:u64, tags:vector<u8>, packages:vector<vector<u8>>, package_types:vector<u64>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, original_goods_id: u128){
        Market::put_on_v2(&sender, title,sell_way,fixed_price,gtype,tags,packages,package_types, type, base_price, add_price, image, resource_url, desc, has_in_kind, end_time, amount, original_goods_id);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::put_on_nft_v2 --arg <...>
    public(script) fun put_on_nft_v2(sender: signer, nft_id: u64,sell_way:u64, fixed_price:u128, tags:vector<u8>,version:u64, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) {
        Market::put_on_nft_v2(&sender, nft_id,sell_way,fixed_price,tags,version, base_price, add_price, end_time, original_goods_id);
    }

    //account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::pull_off_v2 --arg <...>
    public(script) fun pull_off_v2(sender: signer, goods_id: u128) {
        Market::pull_off_v2(&sender, goods_id);
    }

    // account execute-function -b --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::bid_v2 --arg <...>
    public(script) fun bid_v2(sender: signer, seller: address, goods_id: u128, price: u128, quantity: u64) {
        Market::bid_v2(&sender, seller, goods_id, price, quantity);
    }

    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::settlement_v2 --arg <...>
    public(script) fun settlement_v2(sender: signer, seller: address, goods_id: u128) {
        Market::settlement_v2(&sender, seller, goods_id);
    }

    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::buy_now_v2 --arg <...>
    public(script) fun buy_now_v2(sender: signer, seller: address, goods_id: u128, quantity: u64) {
        Market::buy_now_v2(&sender, seller, goods_id,quantity);
    }

    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::open_box_v2 --arg <...>
    public(script) fun open_box_v2(sender: signer,  nft_id: u64, quantity: u64) {
        Market::open_box_v2(&sender, nft_id,quantity);
    }
    
    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::cancel_goods_v2 --arg <...>
    public(script) fun cancel_goods_v2(sender: signer,seller:address, goods_id: u128)  {
        Market::cancel_goods_v2(&sender, seller,goods_id);
    }
    
    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::sync_market_v2 --arg <...>
    public(script) fun sync_market_v2(sender: signer) {
        Market::sync_market_v2(&sender);
    }
    
    // account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::set_lock_v2 --arg <...>
    public(script) fun set_lock_v2(sender: signer, is_lock: bool) {
        Market::set_lock_v2(&sender, is_lock);
    }

    public(script) fun update_meta_v2(sender: signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>){
        Market::update_meta_v2(&sender, title, desc, image);
    }

    public(script) fun create_test_data_v2(sender: signer) {
        Market::create_test_data_v2(&sender);
    }
}
}