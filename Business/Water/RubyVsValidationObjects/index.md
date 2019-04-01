# DON'T USE VALIDATION OBJECTS, USE RUBY!

Recently, 28/03/2019, the gold standard has been to make a InfoNet validation object to check consistency in survey and model data.

Data validation objects generally serve 3 functions:

* They check whether fields comply with choice lists (a set of options for the column).
* They check data consistency with surrounding database objects (standard infonet checks).
* They can run custom checks built with SQL.

The validation object, although it is a good way to help engineers build validation rules quickly, the rules are quite often going to give false positives. As an example, let's ensure that all Xs and Ys are filled in. Well that will fail when a surveyor is unable to find a manhole. A blank X and Y coordinate is exactly what you should have in the case of UTF manholes.

Okay so automatically we have an issue where validation errors might give false positives. This is why basic validation is often not great. But what about custom SQL validations?

Sure these will fix this particular issue, however let's look at another example. Let's say diameters should be within the range 200mm to 900mm. This is a good rule for small models / networks, but for larger ones these validation rules will still give false positives, which consume more of our time.

Wouldn't it be cool if we could flag pipes outside of ranges dependant on the total length of all pipes upstream? Or only throw warnings where a large diameter pipe is used where there is no hydraulic restrictions?

Now we are starting to get into the realms where validating with ruby becomes more required.

```ruby

```

