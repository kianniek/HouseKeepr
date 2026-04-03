const String defaultShoppingProductsCsv =
    '''Section_NL,Section_EN,Product_NL,Product_EN
Alcohol,Alcohol,Bier,Beer
Alcohol,Alcohol,Speciaalbier,Craft beer / Specialty beer
Alcohol,Alcohol,Radler,Radler (Lemon beer)
Alcohol,Alcohol,Rode wijn,Red wine
Alcohol,Alcohol,Witte wijn,White wine
Alcohol,Alcohol,Rosé,Rosé
Alcohol,Alcohol,Cider,Cider
Alcohol,Alcohol,Likeur,Liqueur
Alcohol,Alcohol,Jenever,Gin (Dutch style)
Alcohol,Alcohol,Port,Port wine
Baby,Baby,Luiers,Diapers
Baby,Baby,Babydoekjes,Baby wipes
Baby,Baby,Babyvoeding (Potje),Baby food (Jar)
Baby,Baby,Opvolgmelk,Formula milk
Bakkerij,Bakkerij,Brood (Bruin),Bread (Brown/Whole wheat)
Bakkerij,Bakkerij,Brood (Wit),Bread (White)
Bakkerij,Bakkerij,Volkoren brood,Whole grain bread
Bakkerij,Bakkerij,Speltbrood,Spelt bread
Bakkerij,Bakkerij,Roggebrood,Rye bread
Bakkerij,Bakkerij,Bolletjes,Bread rolls
Bakkerij,Bakkerij,Pistolet,Hard roll
Bakkerij,Bakkerij,Croissant,Croissant
Bakkerij,Bakkerij,Stokbrood,Baguette
Bakkerij,Bakkerij,Krentenbollen,Currant buns
Bakkerij,Bakkerij,Eierkoeken,Egg cakes
Bakkerij,Bakkerij,Beschuit,Rusks
Bakkerij,Bakkerij,Ontbijtkoek,Gingerbread/Breakfast cake
Bakkerij,Bakkerij,Worstenbroodje,Sausage roll
Bakproducten,Baking,Bloem,Flour
Bakproducten,Baking,Zelfrijzend bakmeel,Self-raising flour
Bakproducten,Baking,Suiker,Sugar
Bakproducten,Baking,Vanillesuiker,Vanilla sugar
Bakproducten,Baking,Basterdsuiker,Caster sugar (Brown/White)
Bakproducten,Baking,Poedersuiker,Powdered sugar
Bakproducten,Baking,Gist,Yeast
Bakproducten,Baking,Bakpoeder,Baking powder
Bakproducten,Baking,Pannenkoekenmix,Pancake mix
Conserven,Canned & Jarred,Appelmoes,Apple sauce
Conserven,Canned & Jarred,Soep (Blik/Zak),Soup (Can/Bag)
Conserven,Canned & Jarred,Tomatenpuree,Tomato paste
Conserven,Canned & Jarred,Gezeefde tomaten,Passata
Conserven,Canned & Jarred,Maïs,Corn
Conserven,Canned & Jarred,Doperwten,Peas
Conserven,Canned & Jarred,Bruine bonen,Brown beans
Conserven,Canned & Jarred,Kikkererwten,Chickpeas
Conserven,Canned & Jarred,Augurken,Pickles
Conserven,Canned & Jarred,Zilveruitjes,Pickled onions
Frisdrank en Sap,Soda and Juice,Cola,Cola
Frisdrank en Sap,Soda and Juice,Sinaasappelsap,Orange juice
Frisdrank en Sap,Soda and Juice,Appelsap,Apple juice
Frisdrank en Sap,Soda and Juice,Water (Koolzuurhoudend),Water (Sparkling)
Frisdrank en Sap,Soda and Juice,Water (Plat),Water (Still)
Frisdrank en Sap,Soda and Juice,Limonadesiroop,Cordial/Syrup
Frisdrank en Sap,Soda and Juice,Ice Tea,Iced Tea
Frisdrank en Sap,Soda and Juice,Energiedrank,Energy drink
Fruit,Fruit,Appel,Apple
Fruit,Fruit,Banaan,Banana
Fruit,Fruit,Sinaasappel,Orange
Fruit,Fruit,Druiven,Grapes
Fruit,Fruit,Aardbeien,Strawberries
Fruit,Fruit,Citroen,Lemon
Fruit,Fruit,Limoen,Lime
Fruit,Fruit,Peer,Pear
Fruit,Fruit,Watermeloen,Watermelon
Fruit,Fruit,Frambozen,Raspberries
Fruit,Fruit,Blauwe bessen,Blueberries
Fruit,Fruit,Mandarijn,Mandarin
Fruit,Fruit,Kiwi,Kiwi
Fruit,Fruit,Mango,Mango
Fruit,Fruit,Avocado,Avocado
Groenten,Vegetables,Aardappel (Vastkokend),Potato (Waxy/Firm)
Groenten,Vegetables,Aardappel (Kruimig),Potato (Floury/Starchy)
Groenten,Vegetables,Ui,Onion
Groenten,Vegetables,Rode ui,Red onion
Groenten,Vegetables,Knoflook,Garlic
Groenten,Vegetables,Tomaat,Tomato
Groenten,Vegetables,Cherrytomaten,Cherry tomatoes
Groenten,Vegetables,Komkommer,Cucumber
Groenten,Vegetables,Paprika,Bell Pepper
Groenten,Vegetables,Wortel,Carrot
Groenten,Vegetables,Winterpeen,Large carrot (for stew)
Groenten,Vegetables,Sla,Lettuce
Groenten,Vegetables,Rucola,Arugula/Rocket
Groenten,Vegetables,Spinazie,Spinach
Groenten,Vegetables,Broccoli,Broccoli
Groenten,Vegetables,Champignons,Mushrooms
Groenten,Vegetables,Courgette,Zucchini
Groenten,Vegetables,Aubergine,Eggplant/Aubergine
Groenten,Vegetables,Prei,Leek
Groenten,Vegetables,Bloemkool,Cauliflower
Groenten,Vegetables,Sperziebonen,Green beans
Groenten,Vegetables,Boerenkool,Kale
Groenten,Vegetables,Witlof,Chicory
Groenten,Vegetables,Spruitjes,Brussels sprouts
Groenten,Vegetables,Asperges,Asparagus
Groenten,Vegetables,Zoete aardappel,Sweet potato
Huishouden,Household,Wasmiddel,Laundry detergent
Huishouden,Household,Wasverzachter,Fabric softener
Huishouden,Household,Afwasmiddel,Dish soap
Huishouden,Household,Vaatwastabletten,Dishwasher tablets
Huishouden,Household,Vuilniszakken,Bin liners/Trash bags
Huishouden,Household,Toiletpapier,Toilet paper
Huishouden,Household,Keukenrol,Paper towel
Huishouden,Household,Allesreiniger,All-purpose cleaner
Huishouden,Household,Bleek,Bleach
Huishouden,Household,Sponsjes,Sponges
Huisdieren,Pets,Hondenvoer,Dog food
Huisdieren,Pets,Kattenvoer,Cat food
Huisdieren,Pets,Kattenbakvulling,Cat litter
Internationaal,International,Rijst,Rice
Internationaal,International,Zilvervliesrijst,Brown rice
Internationaal,International,Pasta (Penne/Fusilli),Pasta (Penne/Fusilli)
Internationaal,International,Spaghetti,Spaghetti
Internationaal,International,Noedels,Noodles
Internationaal,International,Sojasaus,Soy sauce
Internationaal,International,Ketjap Manis,Sweet soy sauce
Internationaal,International,Sambal,Chili paste
Internationaal,International,Kokosmelk,Coconut milk
Internationaal,International,Taco schelpen,Taco shells
Internationaal,International,Pindakaas,Peanut butter
Internationaal,International,Currypasta,Curry paste
Internationaal,International,Tortilla wraps,Tortilla wraps
Internationaal,International,Couscous,Couscous
Kaas en Zuivel,Cheese and Dairy,Melk (Halfvol),Milk (Semi-skimmed)
Kaas en Zuivel,Cheese and Dairy,Melk (Vol),Milk (Whole)
Kaas en Zuivel,Cheese and Dairy,Karnemelk,Buttermilk
Kaas en Zuivel,Cheese and Dairy,Chocolademelk,Chocolate milk
Kaas en Zuivel,Cheese and Dairy,Vla,Custard (Dutch style)
Kaas en Zuivel,Cheese and Dairy,Kaas (Jong),Cheese (Young/Mild)
Kaas en Zuivel,Cheese and Dairy,Kaas (Belegen),Cheese (Mature)
Kaas en Zuivel,Cheese and Dairy,Kaas (Oud),Cheese (Aged/Sharp)
Kaas en Zuivel,Cheese and Dairy,Geraspte kaas,Grated cheese
Kaas en Zuivel,Cheese and Dairy,Geitenkaas,Goat cheese
Kaas en Zuivel,Cheese and Dairy,Smeerkaas,Spread cheese
Kaas en Zuivel,Cheese and Dairy,Roomkaas,Cream cheese
Kaas en Zuivel,Cheese and Dairy,Mozzarella,Mozzarella
Kaas en Zuivel,Cheese and Dairy,Brie,Brie
Kaas en Zuivel,Cheese and Dairy,Eieren,Eggs
Kaas en Zuivel,Cheese and Dairy,Boter (Roomboter),Butter (Real butter)
Kaas en Zuivel,Cheese and Dairy,Margarine,Margarine
Kaas en Zuivel,Cheese and Dairy,Yoghurt (Griekse),Yoghurt (Greek)
Kaas en Zuivel,Cheese and Dairy,Kwark,Quark/Cottage cheese
Kaas en Zuivel,Cheese and Dairy,Slagroom,Whipped cream
Koffie en Thee,Coffee and Tea,Koffiebonen,Coffee beans
Koffie en Thee,Coffee and Tea,Gemalen koffie,Ground coffee
Koffie en Thee,Coffee and Tea,Koffiepads,Coffee pods
Koffie en Thee,Coffee and Tea,Koffiecups,Coffee capsules
Koffie en Thee,Coffee and Tea,Thee (Zwart),Tea (Black)
Koffie en Thee,Coffee and Tea,Thee (Groen),Tea (Green)
Koffie en Thee,Coffee and Tea,Koffiemelk,Coffee creamer/milk
Kruiden,Herbs and Spices,Zout,Salt
Kruiden,Herbs and Spices,Zwarte peper,Black pepper
Kruiden,Herbs and Spices,Olijfolie,Olive oil
Kruiden,Herbs and Spices,Zonnebloemolie,Sunflower oil
Kruiden,Herbs and Spices,Azijn,Vinegar
Kruiden,Herbs and Spices,Balsamico,Balsamic vinegar
Kruiden,Herbs and Spices,Basilicum,Basil
Kruiden,Herbs and Spices,Oregano,Oregano
Kruiden,Herbs and Spices,Kaneel,Cinnamon
Kruiden,Herbs and Spices,Gember,Ginger
Kruiden,Herbs and Spices,Paprikapoeder,Paprika powder
Kruiden,Herbs and Spices,Kerriepoeder,Curry powder
Kruiden,Herbs and Spices,Bouillonblokjes,Bouillon cubes/Stock cubes
Ontbijt,Breakfast,Havermout,Oats/Oatmeal
Ontbijt,Breakfast,Muesli,Muesli
Ontbijt,Breakfast,Cruesli,Crunchy muesli
Ontbijt,Breakfast,Cornflakes,Cornflakes
Ontbijt,Breakfast,Hagelslag,Chocolate sprinkles
Ontbijt,Breakfast,Vlokken,Chocolate flakes
Ontbijt,Breakfast,Jam,Jam/Jelly
Ontbijt,Breakfast,Honing,Honey
Ontbijt,Breakfast,Appelstroop,Apple syrup
Sauzen,Sauces,Mayonaise,Mayonnaise
Sauzen,Sauces,Fritessaus,Fries sauce (Lighter mayo)
Sauzen,Sauces,Ketchup,Ketchup
Sauzen,Sauces,Currysaus,Curry ketchup
Sauzen,Sauces,Mosterd,Mustard
Sauzen,Sauces,Satésaus / Pindasaus,Satay sauce
Sauzen,Sauces,Knoflooksaus,Garlic sauce
Snoep en Snacks,Candy and Snacks,Chips (Naturel),Chips/Crisps (Salted)
Snoep en Snacks,Candy and Snacks,Chips (Paprika),Chips/Crisps (Paprika)
Snoep en Snacks,Candy and Snacks,Chocolade (Puur),Chocolate (Dark)
Snoep en Snacks,Candy and Snacks,Chocolade (Melk),Chocolate (Milk)
Snoep en Snacks,Candy and Snacks,Koekjes,Cookies/Biscuits
Snoep en Snacks,Candy and Snacks,Stroopwafels,Stroopwafels (Syrup waffles)
Snoep en Snacks,Candy and Snacks,Speculaas,Spiced biscuits
Snoep en Snacks,Candy and Snacks,Drop,Liquorice
Snoep en Snacks,Candy and Snacks,Nootjes,Nuts
Snoep en Snacks,Candy and Snacks,Borrelnootjes,Coated peanuts
Verzorging,Personal Care,Tandpasta,Toothpaste
Verzorging,Personal Care,Tandenborstel,Toothbrush
Verzorging,Personal Care,Shampoo,Shampoo
Verzorging,Personal Care,Douchegel,Shower gel
Verzorging,Personal Care,Deodorant,Deodorant
Verzorging,Personal Care,Scheerschuim,Shaving cream
Verzorging,Personal Care,Scheermesjes,Razor blades
Verzorging,Personal Care,Maandverband,Sanitary pads
Verzorging,Personal Care,Tampons,Tampons
Verzorging,Personal Care,Paracetamol,Paracetamol
Vlees en Vis,Meat and Fish,Kipfilet,Chicken breast
Vlees en Vis,Meat and Fish,Kippenpoten,Chicken legs
Vlees en Vis,Meat and Fish,Gehakt (Rund),Minced meat (Beef)
Vlees en Vis,Meat and Fish,Gehakt (Half-om-half),Minced meat (Pork/Beef mix)
Vlees en Vis,Meat and Fish,Rundvlees,Beef
Vlees en Vis,Meat and Fish,Biefstuk,Steak
Vlees en Vis,Meat and Fish,Varkensvlees,Pork
Vlees en Vis,Meat and Fish,Karbonade,Pork chop
Vlees en Vis,Meat and Fish,Spekjes,Bacon bits
Vlees en Vis,Meat and Fish,Rookworst,Smoked sausage (Dutch)
Vlees en Vis,Meat and Fish,Zalm,Salmon
Vlees en Vis,Meat and Fish,Tonijn,Tuna
Vlees en Vis,Meat and Fish,Haring,Herring
Vlees en Vis,Meat and Fish,Garnalen,Shrimp
Vleeswaren,Cold Cuts,Ham,Ham
Vleeswaren,Cold Cuts,Kipfilet (beleg),Chicken breast slices
Vleeswaren,Cold Cuts,Salami,Salami
Vleeswaren,Cold Cuts,Boterhamworst,Luncheon meat
Vleeswaren,Cold Cuts,Filet Americain,Filet Americain (Raw beef spread)
Vriezer,Freezer,IJs,Ice cream
Vriezer,Freezer,Diepvriespizza,Frozen pizza
Vriezer,Freezer,Diepvrieserwten,Frozen peas
Vriezer,Freezer,Patat / Friet,Fries / Chips
Vriezer,Freezer,Vissticks,Fish fingers
Vriezer,Freezer,Bitterballen,Bitterballen (Dutch meat snacks)
Vriezer,Freezer,Frikandel,Frikandel (Dutch sausage snack)
Vriezer,Freezer,Kroket,Croquette
Vegetarisch,Vegetarian,Tofu,Tofu
Vegetarisch,Vegetarian,Tempeh,Tempeh
Vegetarisch,Vegetarian,Vegaburger,Veggie burger
Vegetarisch,Vegetarian,Vega gehakt,Vegetarian mince''';
