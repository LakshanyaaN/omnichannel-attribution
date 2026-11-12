# Normalization Analysis: Functional Dependencies & Normal Forms

## 1. Introduction
Database normalization reduces data redundancy and prevents update, insertion, and deletion anomalies. This document provides formal functional dependency (FD) analyses for the relational components of the Omnichannel Attribution Engine and details the rationale for intentional analytical denormalization.

---

## 2. Functional Dependency Analysis

### 2.1 Table: `dim_user`
- **Attributes:** $\{ \text{user\_id}, \text{email}, \text{country}, \text{device\_preference}, \text{first\_seen\_ts} \}$
- **Candidate Keys:** $\{ \text{user\_id} \}, \{ \text{email} \}$
- **Primary Key:** $\text{user\_id}$
- **Functional Dependencies:**
  1. $\text{user\_id} \to \text{email}, \text{country}, \text{device\_preference}, \text{first\_seen\_ts}$
  2. $\text{email} \to \text{user\_id}, \text{country}, \text{device\_preference}, \text{first\_seen\_ts}$

**Evaluation:**
- **1NF:** All attribute domains are atomic (scalar values, no multi-valued or nested structures).
- **2NF:** No partial dependencies exist; all non-prime attributes depend on the entire candidate key.
- **3NF:** No transitive dependencies ($X \to Y$ and $Y \to Z$ where $Y$ is not a superkey).
- **BCNF:** For every non-trivial functional dependency $X \to Y$, the determinant $X$ is a superkey.  
$\implies$ **Satisfies BCNF.**

---

### 2.2 Table: `dim_campaign` & Subclasses
- **Attributes:** $\{ \text{campaign\_id}, \text{name}, \text{channel}, \text{is\_active}, \text{created\_at} \}$
- **Candidate Keys:** $\{ \text{campaign\_id} \}, \{ \text{name} \}$
- **Functional Dependencies:**
  1. $\text{campaign\_id} \to \text{name}, \text{channel}, \text{is\_active}, \text{created\_at}$
  2. $\text{name} \to \text{campaign\_id}, \text{channel}, \text{is\_active}, \text{created\_at}$

**Subclasses:**
- `dim_paid_campaign`: $\text{campaign\_id} \to \text{cpc\_bid}, \text{target\_network}, \text{daily\_budget}$
- `dim_email_campaign`: $\text{campaign\_id} \to \text{sender\_domain}, \text{template\_id}, \text{audience\_segment}$

**Evaluation:**
All determinants are candidate keys.  
$\implies$ **Satisfies BCNF.**

---

### 2.3 Table: `fact_conversion` & `fact_refund`
- `fact_conversion`: $\text{conversion\_id} \to \text{user\_id}, \text{order\_id}, \text{gross\_revenue}, \text{net\_revenue}, \text{conversion\_ts}$
  - Candidate keys: $\{ \text{conversion\_id} \}, \{ \text{order\_id} \}$.
  - In addition, $\text{net\_revenue} \le \text{gross\_revenue}$ is enforced via a domain check constraint.
  - $\implies$ **Satisfies BCNF.**
- `fact_refund`: $\text{refund\_id} \to \text{conversion\_id}, \text{refund\_amount}, \text{refund\_ts}, \text{reason}$
  - Candidate key: $\{ \text{refund\_id} \}$.
  - $\implies$ **Satisfies BCNF.**

---

## 3. Deliberate Analytical Denormalization (OLAP Star Schema)

While transactional and master entities strictly adhere to **BCNF**, certain dimensions and fact tables are consciously denormalized:

### 3.1 Dimension: `dim_date`
In pure 3NF, calendar dates would decompose into:
- $\text{Date} \to \text{Month} \to \text{Quarter} \to \text{Year}$
- Transitive dependencies exist: $\text{month\_number} \to \text{quarter} \to \text{year}$.

**Design Rationale:**  
Analytical attribution queries aggregate metrics by week, month, and fiscal quarter across millions of touchpoints. De-normalizing `dim_date` eliminates 3 runtime relational joins per query, enabling constant-time $O(1)$ attribute lookups without update anomalies (since calendar dates are immutable).

### 3.2 Pre-computed Stored Columns
- `fact_touchpoint.touchpoint_date`: Computed as `touchpoint_ts::DATE`.
- `dim_creative.headline_tsv`: Computed as `to_tsvector('english', headline || ' ' || body_text)`.

These stored generated columns trade a negligible amount of storage for substantial gains in indexing performance (`CREATE INDEX ... USING GIN`).
