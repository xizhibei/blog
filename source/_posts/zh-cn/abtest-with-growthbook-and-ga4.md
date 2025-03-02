---
title: 如何使用 GrowthBook 和 GA4 搭建数据驱动的 A/B 测试系统
tags:
  - GrowthBook
  - Google Analytics
  - A/B 测试
  - 数据驱动
  - BigQuery
categories:
  - 数据分析
date: 2025-03-02 22:15:50
---

你是否遇到过这些困扰：

- 新功能上线后，不确定是否真的提升了用户体验？比如那个经过团队反复打磨的新版注册流程，到底有没有提高转化率？
- 产品决策往往依赖于经验和直觉，缺乏数据支持？"我觉得用户会喜欢蓝色按钮"，但事实真的如此吗？
- 想做 A/B 测试，但不知道如何搭建一套可靠的实验系统？各种测试工具眼花缭乱，从何入手？

作为一名一直在创业公司资深折腾者，我深深理解这种困扰。在经历了多个产品迭代以及公司的起伏后，我逐渐意识到：没有数据支撑的决策就像在黑暗中摸索。如果你也有类似困惑，那么本文正是为你准备的。我们将详细介绍如何使用 GrowthBook 和 GA4 搭建一个完整的 A/B 测试系统，让数据驱动决策不再是一句空话。

### A/B 测试简介

A/B 测试是一种统计方法，用于比较两个或多个版本的策略或产品，以确定哪个版本更有效。它通过随机分配用户到不同的版本，并测量每个版本的效果来实现这一点。

那么，我们为什么要做 A/B 测试？

- **确定哪个版本更有效**：通过数据量化不同版本的表现，例如比较新旧注册流程的转化率（从访问注册页到完成注册的比例）。比如，你可以将传统的三步注册流程与新的单页注册表单进行对比，会发现单页版本提升了不少的转化率。
- **优化产品或策略**：基于实际用户行为做出改进。比如测试不同的定价策略（¥99/月 vs ¥999/年）、功能展示方式（功能列表 vs 交互式演示）或营销文案（强调功能 vs 强调效果）。
- **减少不确定性**：避免基于主观判断的全量发布带来的风险。通过在小范围内（如 10% 的用户）进行测试，及早发现潜在问题。例如在测试新的支付流程时，先用 5% 的流量验证系统稳定性和用户体验。
- **提高决策质量**：用数据说话，避免团队内部无休止的争论。如在讨论首页设计方案时，不同团队成员可能各持己见，但 A/B 测试的结果能够客观地显示哪个版本的跳出率更低、停留时间更长。

接下来，我们来看下如何使用 GrowthBook 和 GA4 搭建一个完整的 A/B 测试系统。

### GrowthBook 简介

GrowthBook 是一个开源的功能标记和 A/B 测试平台，它提供了：

- **功能标志管理**：支持布尔值、数字、字符串和 JSON 类型的功能标志，允许团队通过百分比发布或 A/B 实验逐步推出新功能。
- **实验分析**：通过连接数据源（如 SQL 数据仓库、Mixpanel 和 Google Analytics），GrowthBook 能够查询实验数据并生成可重用的指标库，支持二项式、计数和持续时间等多种指标类型。
- **自定义配置**：提供自定义字段、自定义页面 Markdown 和自定义预启动实验检查表等功能，帮助企业根据需求调整平台。
- **数据集成**：支持多种数据仓库和事件跟踪工具（如 GA4、Segment、Rudderstack 和 Amplitude），并自动生成指标。

### GrowthBook 与 GA4 集成

GrowthBook 与 GA4 的集成非常简单，只需要配置 BigQuery，将 GA4 的数据导出到 BigQuery 中，然后 GrowthBook 就可以通过 BigQuery 来连接 GA4 的数据了。

接下来我们将按以下步骤详细介绍：

1. 客户端接入 GrowthBook SDK
2. 配置 GA4 数据导出到 BigQuery，并在 GrowthBook 中配置 BigQuery 连接
3. 创建功能标志，并在对应客户端进行处理
4. 在 GrowthBook 中创建实验
5. 分析实验结果

#### 1. 客户端接入 GrowthBook SDK

这里我们使用的是 GrowthBook 的 JavaScript SDK，你可以在 [GrowthBook 官方文档](https://docs.growthbook.io/lib/js) 中找到详细的接入文档。

```bash
npm install @growthbook/growthbook
```

然后我们就可以在客户端接入 GrowthBook SDK 了，这里我们使用的是 autoAttributesPlugin 插件，它可以自动将用户的属性（如用户 ID、OS、浏览器、设备等）添加到实验中。

```javascript
import { GrowthBook } from '@growthbook/growthbook';
import { autoAttributesPlugin } from "@growthbook/growthbook/plugins";

const growthbook = new GrowthBook({
  apiHost: "https://cdn.growthbook.io",
  clientKey: "sdk-abc123",
  plugins: [
    autoAttributesPlugin({}),
  ],
  trackingCallback: (experiment, result) => {
    // 发送数据到 GA4
    gtag('event', 'experiment_viewed', {
      experiment_id: experiment.key,
      variant_id: result.variationId
    });
  }
});
```

这里需要特别注意 attribute 的设置，因为 GrowthBook 会根据 attribute 来决定用户是否纳入实验，我们第一次接入的时候，就因为 attribute 设置错误，导致获取实验数据异常。

#### 2. 配置 GA4 数据导出到 BigQuery，并在 GrowthBook 中配置 BigQuery 连接

这一步的前提是你有 GA4 的管理权限，并且开通了 GCP 服务。官方文档 [A/B Testing with Google Analytics 4 (GA4) and GrowthBook](https://docs.growthbook.io/guide/GA4-google-analytics) 中详细介绍了如何配置 GA4 数据导出到 BigQuery，这里就不赘述了。

在这个的基础上，我补充两个注意事项：

1. 在 GA4 中配置数据导出时，导出的频率可以把 Streaming 选上，也就是能看到尽可能实时的数据。
2. 在 GrowthBook 中配置 BigQuery 连接时，Default Dataset 需要一次性填写正确，不然其它的分析功能可能会报错，并且不能正常帮你生成一些常见的配置项目（比如 Fact Tables, Metrics 等）。

#### 3. 创建功能标志，并在对应客户端进行处理

常见的 AB 测试，一般会涉及控制组和实验组，而具体的实现方式就是用功能标志或者说功能开关，在 GrowthBook 中，它提供了多种类型的功能标志，比如布尔值、数字、字符串和 JSON 类型。多数情况下，我们只需要用到布尔值类型，也就是我们常说的开关，这在我们上线新功能时，可以很方便地控制新功能是否开启，也就是这时候非常适合进行 AB 测试。

图片来自于[这里](https://docs.growthbook.io/features/basics)
![功能标志创建](/media/17409248371440/20250302215340.png)  

然后，在客户端进行处理，比如：

```javascript
// 实验示例
if (growthbook.isOn("new-feature")) {
  // 显示新功能
} else {
  // 显示原有功能
}
```

#### 4. 在 GrowthBook 中创建一次实验

在 GrowthBook 中创建 AA 实验时，需要选择对应的功能标志并设置实验变量。以首页按钮实验为例，我们需要添加按钮点击事件的上报。这里特意选择 AA 实验（而不是 AB 实验）是因为在首次集成 GrowthBook 和 GA4 时，我们需要验证配置是否正确。

> 小知识：AA 实验是 A/B 测试的一种特殊形式，它将用户随机分成两组，但两组用户看到的是完全相同的版本。如果系统配置正确，两组的数据应该非常接近。如果数据差异显著，则说明配置可能存在问题，需要进行检查。

图片来自于[这里](https://docs.growthbook.io/feature-flag-experiments)

![实验创建](/media/17409248371440/20250302215449.png)  

然后点击开始实验，GA4 就会开始收集数据。

你可以在 BigQuery 中确认数据是否正常收集。

```sql
select * 
from `analytics_[your_property_id].events_intraday_*`
where event_name = 'experiment_viewed'
order by event_timestamp desc
limit 10;
```

请把 `[your_property_id]` 替换为你的 GA4 的 property id，如果你能看到数据，并且 event_params 中包含 experiment_id 和 variant_id，其中 experiment_id 就是我们实验的 key，variant_id 就是我们实验的变量，那么就说明数据正常收集了。

![BigQuery 数据](/media/17409248371440/20250302215216.png)  

#### 5. 分析结果

最后，我们可以在 GrowthBook 中查看实验结果，并进行分析。

这里我们可以选择实验开始前埋的点击事件的点击率作为 Goal Metrics，也就是想要达到的目的指标，然后随机选择一个指标作为 Secondary Metrics，比如： Sessions per User
或者 Pages per Session。

![实验配置 Metrics](/media/17409248371440/20250302214902.png)

同时需要注意的是，GrowthBook 提供了 Frequentist 和 Bayesian 两种统计分析引擎，业界一般用 Frequentist， 也就是想要用 P 值来判断实验结果是否显著。

![统计分析引擎配置](/media/17409248371440/20250302215048.png)  

最后，点击 Update 按钮，我们就可以看到实验的结果了（图片来自于[这里](https://docs.growthbook.io/app/experiment-results#frequentist-engine)）。

![实验结果](/media/17409248371440/20250302215741.png)  

### 总结

通过结合 GrowthBook 和 GA4，我们可以构建一个强大的 A/B 测试系统。关键是要注意实验设计、数据收集和结果分析的各个环节，确保测试的科学性和有效性。

### P.S.

为什么选择 GrowthBook 而不是其他 A/B 测试工具？

- 我们公司目前主要的统计分析工具是 GA4，所以选择 GrowthBook 可以让我们更方便地与 GA4 集成。
- GrowthBook 的 SDK 是开源的，即使是它的 Cloud 版本也不贵，你可以在 [GitHub](https://github.com/growthbook/growthbook) 上找到它，如果以后有定制需求，也可以自己动手修改。
- AB 测试方法论已经非常成熟了，其它的工具也非常多，目前 GrowthBook 能满足我们现阶段的需求，就不需要再花过多的时间去折腾其他工具了。
