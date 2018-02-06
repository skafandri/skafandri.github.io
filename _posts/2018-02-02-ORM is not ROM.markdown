---
layout: post
title:  "ORM is not ROM"
date:   2018-01-01 00:00:00
categories: orm doctrine symfony design database
---

![docker symfony]({{"/images/orm-hate.png"}})
> <span font-size="1em">Image credit: Martin Fowler https://martinfowler.com/bliki/OrmHate.html</span>


ORM libraries provide mapping capabilities between relational data sitting in a RDBMS and objects interacting in memory. And like all developers tools, they are sometimes misused. When using an ORM we are supposed to map objects interactions to a relational model. Often we end up mapping a relational model using OOP syntax.

I have compiled a short list of *anti-patterns* I encountered the most often in code bases. Certainly there are more out-here.  I propose a possible solution for the situation at hands.

In the following example we will suppose the worst case scenario. That is we have to map an existing database which is currently used by other systems. In short, we can't change the database in any way.


### Map bad column names to bad properties and accessors names
Naming things in software (besides being hard) can have a tremendous effect on code readability.
By default, an ORM will map each database column to a property with the same or a curated name.

One example was a table that had 2 columns **delivery** and **delivery1**. After checking the existing records, it was clear that those columns actually contained **delivery_type** and **delivery_fee** informations. There is a popular misconception of trying to *reflect* the database in the mapping.  
The following mapping is perfectly valid.
````
/**
 * @ORM\Column(name="delivery", type="integer")
 */
private $deliveryType;

/**
 * @ORM\Column(name="delivery1", type="integer")
 */
private $deliveryFee;
````

This small difference can have a big impact on the code readability. The following snippet could be hard to understand
````
if ($order->getDelivery() === 3) {
    $order->setDelivery1($order->getDelivery1()+10);
}
````
After renaming (and a small improvement), it could be easier to understand
````
if ($order->getDeliveryType() === Delivery::COURIER) {
    $order->setDeliveryFee($order->getDeliveryFee()+10);
}
````
The same technique applies to bad table names as well, an entity class name does not necessarily match the table name.

### Map a nullable column to a nullable property
When a database column allows `null` as a value, it usually means the absence of a value.
As an example, consider an **order** table with a nullable column **delivery_fee**. A mapped entity would look like
````php
class Order
{
    /**
     * @ORM\Column(type="integer", nullable="true")
     */
    private $deliveryFee;

    public function getDeliveryFee()
    {
        return $this->deliveryFee;
    }

    public function setDeliveryFee($deliveryFee)
    {
        $this->deliveryFee = $deliveryFee;
    }
}
````
Now all the rest of the code will deal with two different data types: integer and null. This will manifest in the code as casts and ifs, like the following example:
````
function someCalculation(Order $order)
{
    $this->total += (int)$order->getDeliveryFee();
}

function someController(Order $order, $deliveryFee)
{
    if ($deliveryFee > 0) {
        $order->setDeliveryFee($deliveryFee);
    }
}
````
One solution is to map null values to a special value of the same data type, and perform the necessary casts and ifs within the mapped entity. The previous entity could be rewritten like this
````
class Order
{
    /**
     * @ORM\Column(type="integer", nullable="true")
     */
    private $deliveryFee;

    public function getDeliveryFee(): int
    {
        return (int)$this->deliveryFee;
    }

    public function setDeliveryFee(int $deliveryFee)
    {
        if ($deliveryFee === 0) {
            $deliveryFee = null;
        }
        $this->deliveryFee = $deliveryFee;
    }
}
````
Now the *nullability* of this column is contained within the entity. As a nice side effect, now we could type-hint the entity methods arguments and return types.

This transformation will result in a simpler calling code.
````
function someCalculation(Order $order)
{
    $this->total += $order->getDeliveryFee();
}

function someController(Order $order, $deliveryFee)
{
    $order->setDeliveryFee($deliveryFee);
}
````


### Map an Enum column to property with getters and setters
Enum here doesn't necessarily mean an SQL `Enum` type. But any column that contain a fixed set of possible values. The following mapping will work with any scalar type of the **state** column (omitted constants definition for brevity).

````php
class Order
{
    /**
     * @ORM\Column(type="integer")
     */
    private $state = self::STATE_NEW;

    public function setState($state)
    {
        if(!in_array($state, [self::STATE_NEW, self::STATE_CONFIRMED, self::STATE_CANCELED])) {
            throw new \InvalidArgumentException("Invalid state");
        }
        $this->state = $state;
    }

    public function getState()
    {
        return $this->state;
    }
}
````
This example makes it hard to find out from where an order can be canceled, or which parts are interested in confirmed orders.

One solution to map Enum like columns, is to hide it behind a set of *issers* and *actions*.  
We can rewrite the previous entity as following
````php
class Order
{
    /**
     * @ORM\Column(type="integer")
     */
    private $state = self::STATE_NEW;

    public function confirm()
    {
        $this->state = self::STATE_CONFIRMED;
    }

    public function isConfirmed()
    {
        return $this->state === self::STATE_CONFIRMED;
    }

    public function cancel()
    {
        $this->state = self::STATE_CANCELED;
    }

    public function isCanceled()
    {
        return $this->state === self::STATE_CANCELED;
    }
}
````

Starting from PHP7.1.0 we can even declare the constants as private to enforce encapsulation.

With this version, one could easily use the IDE's *Find Usages* feature to quickly find who is interested in which status and who is doing what. You may need to handle all states in same parts of the code, fine, a generic `getState` method can be used there. But you should review your design first, most of the time you may find a routine that is doing many things.

This also enables more fine grained changes, we could enhance the `cancel` routine to
````php
public function cancel()
{
    if ($this->state === self::STATE_RETURNED) {
        throw new \LogicException('Cannot cancel a returned order');
    }
    $this->state = self::STATE_CANCELED;
}
````

### Map multipurpose columns to multipurpose properties
Sometimes when a system evolves in an unexpected way, it's database and code base may do the same. This can result in a column holding different types of informations and often related.

In one example, a `group by` on a column named **delivery** returned the values

| delivery       |
| ---------------|
| store          |
| courier        |
| store_online   |
| courier_online |

After looking up more data, it became clear the meaning of those values

| delivery       | meaning                            |
| ---------------|------------------------------------|
| store          | store delivery, cash on delivery   |
| courier        | courier delivery, cash on delivery |
| store_online   | store delivery, paid online        |
| courier_online | courier delivery, paid online      |

We are obviously looking at delivery and payment informations mixed in this column. If we just use the auto-generated mapping, we would end up with a mapping like

````php
class Order
{
    /**
     * @ORM\Column(type="string")
     */
    private $delivery;

    public function getDelivery()
    {
        return $this->delivery;
    }
}
````
Such simplistic mapping would clutter the code with conditionals like
````php
if (
    $order->getDelivery() === Order::DELIVERY_COURIER
    || $order->getDelivery() === Order::DELIVERY_COURIER_ONLINE
) {
    //hand to courier
} else {
    //dispatch to shop
}
````
One possible approach is to expose this column as two classes of accessors one for delivery type and one for payment type

````php
class Order
{
    /**
     * @ORM\Column(type="string")
     */
    private $delivery;

    public function getDeliveryType()
    {
        if (
            $this->delivery === self::DELIVERY_COURIER ||
            $this->delivery === self::DELIVERY_COURIER_ONLINE
        ) {
            return self::DELIVERY_TYPE_COURIER;
        }
        if (
            $this->delivery === self::DELIVERY_STORE ||
            $this->delivery === self::DELIVERY_STORE_ONLINE
        ) {
            return self::DELIVERY_TYPE_STORE;
        }
        return self::DELIVERY_TYPE_NOT_SET;
    }

    public function getPaymentType()
    {
        if (
            $this->delivery === self::DELIVERY_STORE_ONLINE ||
            $this->delivery === self::DELIVERY_COURIER_ONLINE
        ) {
            return self::PAYMENT_TYPE_ONLINE;
        }
        if (
            $this->delivery === self::DELIVERY_STORE ||
            $this->delivery === self::DELIVERY_COURIER
        ) {
            return self::PAYMENT_TYPE_CASH;
        }
        return self::PAYMENT_TYPE_NOT_SET;
    }
}
````
We can also change the database constants visibility to private and completely hide this mess from the rest of the world.

### Map related columns to related properties
- one to one
  order(delivery_date, delivery_address, delivery_status)
- inheritance
  user()
### Map nullable foreign key to nullable relation
NullObject
